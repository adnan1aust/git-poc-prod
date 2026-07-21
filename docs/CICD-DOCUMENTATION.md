# CI/CD Technical Documentation

## Table of Contents

- [Branching Strategy](#branching-strategy)
- [Project Configuration](#project-configuration)
- [Local Development Guardrails](#local-development-guardrails-pre-commit)
- [Workflow 1: Pull Request Validation](#workflow-1-validate-pryml--pull-request-validation)
- [Workflow 2: Deploy to Org](#workflow-2-deployyml--deploy-to-org)
- [Secrets Required](#secrets-required)
- [npm Packages](#key-npm-packages-devdependencies)
- [SF CLI Plugins](#sf-cli-plugins-installed-at-ci-runtime)
- [Pipeline Flow Diagram](#pipeline-flow-diagram)
- [Design Decisions & Trade-offs](#design-decisions--trade-offs)

---

## Branching Strategy

| Branch            | Purpose                                            | Salesforce Org                     | Deployment Mode            |
| ----------------- | -------------------------------------------------- | ---------------------------------- | -------------------------- |
| `uat`             | Integration testing; receives feature/fix branches | UAT org                            | Delta (changed files only) |
| `main`            | Production-ready code                              | Production org                     | Full source deployment     |
| `feat/*`, `fix/*` | Short-lived branches for features or hotfixes      | Validated against target org on PR | N/A (dry-run only)         |

**Flow:** `feature branch` → PR to `uat` → merge → auto-deploy to UAT → PR to `main` → merge → auto-deploy to Prod.

---

## Project Configuration

### `sfdx-project.json`

| Property         | Value                                                 |
| ---------------- | ----------------------------------------------------- |
| Source directory | `force-app` (default package directory)               |
| API Version      | `66.0`                                                |
| Login URL        | `https://login.salesforce.com` (production-type auth) |
| Namespace        | None                                                  |
| Managed packages | None                                                  |

### `package.json`

- **Name:** `salesforce-app`
- **Node requirement:** `>=18.0.0`
- **Private:** `true` (not published to npm)

---

## Local Development Guardrails (Pre-Commit)

**Husky + lint-staged** run automatically on every `git commit`:

| File Pattern                                            | Action                                                                               |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `*.cls, *.cmp, *.html, *.js, *.json, *.xml, *.yml, ...` | `prettier --write` (auto-format)                                                     |
| `**/aura/**/*.js`, `**/lwc/**/*.js`                     | `eslint` (lint check)                                                                |
| `**/lwc/**`                                             | `sfdx-lwc-jest --bail --findRelatedTests --passWithNoTests` (run related unit tests) |

This ensures that code arriving in the remote repository is already formatted, linted, and unit-tested for the affected LWC components.

> Hooks install via the `prepare` script — every developer must run `npm install` once after cloning.

### Consistent Formatting (three enforcement layers)

1. **Editor** — `.vscode/settings.json` sets Prettier as the default formatter with format-on-save (`prettier.requireConfig` ensures the shared `.prettierrc` is used, never personal defaults).
2. **Pre-commit** — Husky + lint-staged run `prettier --write` on staged files.
3. **CI** — `prettier:verify` in `validate-pr.yml` fails any PR containing unformatted code (catches `--no-verify` commits and Git clients that skip hooks).

The committed `.prettierrc` (with `prettier-plugin-apex` and `@prettier/plugin-xml`) plus `.gitattributes` (forced LF line endings) guarantee byte-identical formatting across all developers and platforms.

---

## Workflow 1: `validate-pr.yml` — Pull Request Validation

**Trigger:** Any pull request targeting `uat` or `main`.

**Concurrency:** Grouped by PR number; new pushes to the same PR cancel in-progress runs (`cancel-in-progress: true`).

**Permissions:** `contents: read`, `pull-requests: write` (to post comments).

---

### Job 1: `lint-and-test` — Lint, Format & Unit Test

| Step                     | What it does                                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Checkout**             | Clones the PR branch.                                                                                                                |
| **Setup Node 20**        | Installs Node.js 20.x with npm cache enabled for faster installs.                                                                    |
| **Install dependencies** | `npm ci` — deterministic clean install from lockfile.                                                                                |
| **Prettier verify**      | Runs `prettier --check` on all supported file types. Fails if any file is not formatted.                                             |
| **ESLint**               | Lints all JavaScript in `aura/` and `lwc/` directories. `--no-error-on-unmatched-pattern` prevents failure if no JS files exist yet. |
| **LWC Jest tests**       | Runs `sfdx-lwc-jest --coverage --passWithNoTests`. Generates a code coverage report.                                                 |
| **Upload coverage**      | Stores the `coverage/` directory as a GitHub Actions artifact (5-day retention).                                                     |

---

### Job 2: `code-analysis` — Salesforce Code Analyzer v5 (PMD)

| Step                        | What it does                                                                                                                                                                                                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Install SF CLI**          | `npm install -g @salesforce/cli`                                                                                                                                                                                                                                                     |
| **Install analyzer plugin** | `code-analyzer` (Code Analyzer **v5** — replaces the retired `@salesforce/sfdx-scanner` v4).                                                                                                                                                                                         |
| **Run Code Analyzer**       | `sf code-analyzer run` scans `force-app` with rule selector `SalesforceApexRules` (the custom PMD ruleset registered in `code-analyzer.yml`). Outputs JSON + HTML reports. **Severity threshold: 2** — any finding at severity 1 (Critical) or 2 (High) makes the run exit non-zero. |
| **Job summary**             | Writes a findings table (rule, severity, location, message) to the GitHub Actions job summary.                                                                                                                                                                                       |
| **PR comment**              | Creates/updates a "Code Analyzer Report" comment on the PR with the first 25 findings.                                                                                                                                                                                               |
| **Upload reports**          | JSON + HTML reports stored as the `code-analyzer-report` artifact (5-day retention).                                                                                                                                                                                                 |
| **Gate**                    | Fails the job if the severity threshold was exceeded (or the run errored).                                                                                                                                                                                                           |

> **Private-repo note:** Reporting deliberately uses job summary + PR comment + artifact instead of SARIF upload to the GitHub Security tab, which requires GitHub Advanced Security on private repos.

#### PMD Rules Enforced (`config/pmd-ruleset.xml`)

Code Analyzer v5 derives rule severity from PMD priority (priority 1 → severity 2/High). Rules that must **block** a PR carry an explicit `<priority>1</priority>`; the rest report at Moderate and don't trip the gate.

| Category           | Rules                                                                                                               | Blocking? |
| ------------------ | ------------------------------------------------------------------------------------------------------------------- | --------- |
| **Performance**    | `OperationWithLimitsInLoop` (priority 1); `AvoidDebugStatements`                                                    | Yes / No  |
| **Best Practices** | Tests must have asserts, no `@SeeAllData=true`, avoid `global`, no unused locals                                    | No        |
| **Security**       | CRUD violations, sharing violations, SOQL injection, open redirects, XSS (URL param + EscapeFalse) — all priority 1 | Yes       |
| **Error Prone**    | No hardcoded IDs, no empty catch/if/while blocks, no method-named-like-class                                        | No        |
| **Design**         | Cyclomatic complexity (method ≤ 15, class ≤ 40), parameter list max 5                                               | No        |

#### `code-analyzer.yml` (repo root)

Registers `config/pmd-ruleset.xml` as a custom PMD ruleset (selectable via the `SalesforceApexRules` tag) and disables the analyzer's bundled ESLint engine, since LWC/Aura JavaScript is already linted by the project's own ESLint flat config in the `lint-and-test` job.

---

### Job 3: `validate-deploy` — Validate Deployment & Apex Tests

**Depends on:** `lint-and-test` + `code-analysis` must pass first.

| Step                                   | What it does                                                                                                                                                                                                                                                                                                                                                                  |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Checkout (full history)**            | `fetch-depth: 0` so git-delta can compare branches.                                                                                                                                                                                                                                                                                                                           |
| **Install SF CLI + sfdx-git-delta**    | Delta plugin generates a `package.xml` with only the changed metadata.                                                                                                                                                                                                                                                                                                        |
| **Determine target org**               | If PR targets `main` → authenticate against Prod; otherwise → UAT. Uses corresponding secret (`PROD_SF_AUTH_URL` or `UAT_SF_AUTH_URL`).                                                                                                                                                                                                                                       |
| **Authenticate**                       | Writes the SFDX Auth URL to a temp file, authenticates via `sf org login sfdx-url`, then securely deletes the file.                                                                                                                                                                                                                                                           |
| **Generate delta package**             | Compares the **merge base** of `origin/<base_branch>` and `HEAD` to `HEAD`, so commits on the target branch not yet in the PR branch aren't mis-detected as changes. Produces `delta/package/package.xml` and optionally `delta/destructiveChanges/destructiveChanges.xml`.                                                                                                   |
| **Check for deployable changes**       | If no `package.xml` was generated, posts a PR comment ("no metadata changes") and skips validation.                                                                                                                                                                                                                                                                           |
| **Check for destructive changes**      | Emits a warning annotation in the workflow summary if the PR deletes metadata.                                                                                                                                                                                                                                                                                                |
| **Collect test classes**               | Detects changed non-test Apex (`.cls` **and** `.trigger`). **No Apex in the PR → validation runs without any test level** (the platform runs no tests for a package without Apex, so config-only PRs validate in seconds and show no coverage). Apex changed: looks for `<Name>Test.cls` / `<Name>_Test.cls` → `RunSpecifiedTests`; no match → falls back to `RunLocalTests`. |
| **Validate deployment (dry-run)**      | Runs `sf project deploy start --dry-run` against the target org. This compiles metadata and runs Apex tests server-side without persisting changes. Includes destructive manifest if present. **The step then parses `deploy-result.json` and fails the job if `status != 0`** — a failed validation can never pass green, even on config-only PRs with no Apex changes.      |
| **Check per-class coverage (80% min)** | Only runs when the PR contains Apex. Parses `deploy-result.json`, extracts `codeCoverage` per changed class/trigger, and **fails the pipeline if any has < 80% line coverage**.                                                                                                                                                                                               |
| **Post PR comment**                    | Creates or updates a "Deployment Validation Summary" comment on the PR with components deployed, errors, tests run, and test failures. The per-class coverage table **only lists Apex changed in the PR** — and is omitted entirely when the PR contains no Apex.                                                                                                             |
| **Upload results**                     | Stores `deploy-result.json` as an artifact (5-day retention).                                                                                                                                                                                                                                                                                                                 |

---

## Workflow 2: `deploy.yml` — Deploy to Org

**Trigger:** Push to `uat` or `main` when files under `force-app/**` or `destructiveChanges/**` change.

**Concurrency:** Grouped by branch name; `cancel-in-progress: false` — deployments queue rather than cancel each other to avoid partial deploys.

**Permissions:** `contents: read`.

**Environment:** Maps to GitHub Environment `production` (for `main`) or `uat` (for `uat`). This enables environment-specific secrets and optional manual approval gates configured in GitHub repository settings.

---

### Deployment Behaviour by Branch

| Step                    | `uat` branch                                                                                                                                                               | `main` branch                                        |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| **Deploy mode**         | Delta (only changed files from last commit)                                                                                                                                | Full (`--source-dir force-app`)                      |
| **Plugin**              | `sfdx-git-delta` installed                                                                                                                                                 | Not installed (unused)                               |
| **Delta generation**    | `github.event.before` (branch tip before the push) to `HEAD` — captures multi-commit pushes and merge commits fully; falls back to `HEAD~1` if the base SHA is unavailable | Skipped                                              |
| **Test level**          | `RunLocalTests`                                                                                                                                                            | `RunLocalTests`                                      |
| **Destructive changes** | Appended via `--post-destructive-changes` if detected in delta                                                                                                             | Not included (full source mode)                      |
| **Deployment command**  | `sf project deploy start --manifest delta/package/package.xml ...`                                                                                                         | `sf project deploy start --source-dir force-app ...` |
| **Wait timeout**        | 30 minutes                                                                                                                                                                 | 30 minutes                                           |
| **Verification**        | Parses JSON output; fails if `status != 0`, logs component failures                                                                                                        | Same                                                 |
| **Artifact**            | `deploy-results-uat-<run#>` (10-day retention)                                                                                                                             | `deploy-results-main-<run#>` (10-day retention)      |

---

### Deploy Steps in Detail

| Step                                   | What it does                                                                                                        |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Checkout (full history)**            | `fetch-depth: 0` for delta comparison.                                                                              |
| **Install Salesforce CLI**             | Global install of `@salesforce/cli`.                                                                                |
| **Install sfdx-git-delta**             | Only on non-main branches (delta mode).                                                                             |
| **Determine target org**               | Sets `org_alias`, `test_level`, and `deploy_mode` as job outputs.                                                   |
| **Authenticate**                       | Uses environment-specific secret to log into the target Salesforce org. Auth file is deleted immediately after use. |
| **Generate delta package** (UAT only)  | Creates `delta/package/package.xml` and optionally `delta/destructiveChanges/destructiveChanges.xml`.               |
| **Check for delta changes** (UAT only) | Skips deployment gracefully if no metadata changed.                                                                 |
| **Deploy delta to UAT**                | Deploys only changed components. Includes destructive changes if present.                                           |
| **Deploy full source to Prod**         | Deploys the entire `force-app` directory.                                                                           |
| **Verify deployment**                  | Checks JSON status code. Prints component failures on error.                                                        |
| **Upload deploy results**              | Persists `deploy-result.json` for audit (10-day retention).                                                         |

---

## Secrets Required

| Secret             | Used by        | Purpose                              |
| ------------------ | -------------- | ------------------------------------ |
| `UAT_SF_AUTH_URL`  | Both workflows | SFDX Auth URL for the UAT org        |
| `PROD_SF_AUTH_URL` | Both workflows | SFDX Auth URL for the Production org |

These are Salesforce CLI `force://...` auth URLs stored as GitHub repository or environment secrets. They encode the OAuth refresh token, instance URL, and client credentials needed for headless authentication.

---

## Key npm Packages (devDependencies)

| Package                               | Version  | Purpose                                                  |
| ------------------------------------- | -------- | -------------------------------------------------------- |
| `@salesforce/sfdx-lwc-jest`           | ^7.0.2   | Jest test runner configured for Lightning Web Components |
| `eslint`                              | ^9.29.0  | JavaScript/TypeScript linter                             |
| `@salesforce/eslint-config-lwc`       | ^4.0.0   | Lint rules tailored for LWC JavaScript                   |
| `@salesforce/eslint-plugin-aura`      | ^3.0.0   | Lint rules for Aura components                           |
| `@salesforce/eslint-plugin-lightning` | ^2.0.0   | Additional Lightning platform lint rules                 |
| `@lwc/eslint-plugin-lwc`              | ^3.1.0   | LWC-specific ESLint rules (wire adapters, reactivity)    |
| `eslint-plugin-import`                | ^2.31.0  | Import ordering and validation                           |
| `eslint-plugin-jest`                  | ^28.14.0 | Jest-specific lint rules for test files                  |
| `prettier`                            | ^3.5.3   | Opinionated code formatter                               |
| `@prettier/plugin-xml`                | ^3.4.1   | XML formatting support for Prettier                      |
| `prettier-plugin-apex`                | ^2.2.6   | Apex class/trigger formatting support for Prettier       |
| `husky`                               | ^9.1.7   | Git hooks manager (runs pre-commit hook)                 |
| `lint-staged`                         | ^16.1.2  | Runs linters/formatters only on staged files             |

---

## SF CLI Plugins (Installed at CI Runtime)

| Plugin           | Purpose                                                                                                                                                                                                                             |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sfdx-git-delta` | Generates a minimal `package.xml` containing only metadata changed between two git refs. Used in both PR validation and UAT deployment.                                                                                             |
| `code-analyzer`  | Salesforce Code Analyzer **v5** — static code analysis (PMD 7, Regex, RetireJS; ESLint engine disabled via `code-analyzer.yml`). Used in the PR validation code-analysis job. Replaces the retired `@salesforce/sfdx-scanner` (v4). |

---

## Pipeline Flow Diagram

```
Developer workstation
  │
  │  git commit (husky pre-commit → lint-staged → prettier + eslint + jest)
  │  git push
  ▼
┌─────────────────────────────────────────────────────────────┐
│  Pull Request → uat or main                                  │
│                                                              │
│  ┌──────────────┐   ┌───────────────────┐                   │
│  │ lint-and-test│   │code-analysis (v5) │  (run in parallel) │
│  │  • prettier  │   │  • PMD scan       │                   │
│  │  • eslint    │   │  • summary+comment│                   │
│  │  • jest+cov  │   │  • sev≤2 gate     │                   │
│  └──────┬───────┘   └──────┬────────────┘                   │
│         │                   │                                │
│         └───────┬───────────┘                                │
│                 ▼                                             │
│  ┌──────────────────────────────────────────────────────────┐│
│  │ validate-deploy (needs both above to pass)                ││
│  │  • Generate delta package (changed metadata only)         ││
│  │  • Dry-run deploy to target org                           ││
│  │  • Run Apex tests (specified or all local)                ││
│  │  • Enforce 80% per-class coverage gate                    ││
│  │  • Post PR comment with results table                     ││
│  └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           │
                     Merge (reviewer approval)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Push to uat or main (deploy.yml)                            │
│                                                              │
│  uat:  delta deploy (event.before..HEAD) → UAT org           │
│  main: full source deploy (force-app/) → Prod org            │
│                                                              │
│  • RunLocalTests on both                                     │
│  • Destructive changes applied (UAT delta only)              │
│  • JSON result artifact uploaded                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Design Decisions & Trade-offs

### 1. Delta vs Full Deploy

- **UAT** gets delta deploys for speed — only changed components are pushed to the org, reducing deployment time significantly on large projects.
- **Production** gets a full source deployment to ensure the org stays perfectly in sync with the `main` branch, eliminating drift from accumulated partial deploys.

### 2. Git Comparison Refs

- **PR validation** compares the **merge base** of `origin/<base_branch>` and `HEAD` to `HEAD` — captures everything in the PR without mis-detecting target-branch commits that aren't in the PR branch yet.
- **Post-merge deploy** uses `github.event.before` (the branch tip before the push), so multi-commit pushes and merge commits are fully captured. Falls back to `HEAD~1` when the base SHA is unavailable (e.g., force-push or new branch).

### 3. Concurrency Controls

- **`cancel-in-progress: false` on deploy** — Prevents a rapid succession of merges from canceling a deployment mid-flight, which could leave the org in an inconsistent state.
- **`cancel-in-progress: true` on PR validation** — New pushes to the same PR make prior validation results stale; canceling saves compute resources.

### 4. Coverage Gate (80% Per-Class)

- Stricter than Salesforce's platform-enforced 75% org-wide minimum.
- Enforced **per changed class** to prevent "coverage padding" from unrelated tests boosting overall numbers while the new code remains untested.

### 5. Smart Test Selection

- **PRs without Apex changes run no tests at all** — config-only changes (fields, layouts, flows) validate in seconds and show no coverage table.
- When Apex (class or trigger) changed, the PR workflow identifies matching test classes (`*Test.cls` / `*_Test.cls`) and uses `RunSpecifiedTests` for faster feedback (typically 2-5 minutes vs 10-30 minutes for all local tests).
- Falls back to `RunLocalTests` only when Apex changed but no matching test class is found, ensuring changed code never goes untested.

### 6. GitHub Environments

- The deploy workflow references `production` and `uat` environments, enabling optional deployment protection rules (manual approvals, wait timers, branch restrictions) configured in GitHub repository settings.

### 7. Path-Based Triggering

- Deploy workflow only triggers when files under `force-app/**` or `destructiveChanges/**` change. Documentation-only or config-only commits do not trigger unnecessary deployments.

### 8. Artifact Retention

- PR validation artifacts: 5 days (sufficient for review cycle).
- Deployment artifacts: 10 days (longer for post-deployment debugging).

---

## File Structure Reference

```
.github/
  workflows/
    deploy.yml              # Post-merge deployment workflow
    validate-pr.yml         # Pull request validation workflow
.husky/
  pre-commit              # Triggers lint-staged on commit
code-analyzer.yml          # Code Analyzer v5 config (registers PMD ruleset, disables ESLint engine)
config/
  pmd-ruleset.xml          # Custom PMD rules; priority 1 = blocking in CI
  project-scratch-def.json # Scratch org definition (local dev)
force-app/                 # Salesforce source (metadata + code)
destructiveChanges/        # Manual destructive change manifests
package.json               # Node dependencies and scripts
sfdx-project.json          # Salesforce DX project configuration
```
