/**
 * Tests for AccountController covering happy path, limit enforcement,
 * empty-org scenario, and bulk data handling.
 */
@IsTest
private class AccountControllerTest {
  @TestSetup
  static void setupTestData() {
    TestDataFactory.createAccounts(15, true);
  }

  @IsTest
  static void shouldReturn10Accounts_WhenMoreThan10Exist() {
    // Given — 15 accounts created in @TestSetup

    // When
    Test.startTest();
    List<Account> result = AccountController.getRecentAccounts();
    Test.stopTest();

    // Then
    Assert.areEqual(10, result.size(), 'Should return exactly 10 accounts');
  }

  @IsTest
  static void shouldReturnAccountsOrderedByCreatedDateDescending_WhenCalled() {
    // Given — 15 accounts created in @TestSetup

    // When
    Test.startTest();
    List<Account> result = AccountController.getRecentAccounts();
    Test.stopTest();

    // Then — each record should be as recent as or more recent than the next
    for (Integer i = 0; i < result.size() - 1; i++) {
      Assert.isTrue(
        result[i].CreatedDate >= result[i + 1].CreatedDate,
        'Accounts should be ordered from newest to oldest'
      );
    }
  }

  @IsTest
  static void shouldReturnExpectedFields_WhenCalled() {
    // Given — 15 accounts created in @TestSetup

    // When
    Test.startTest();
    List<Account> result = AccountController.getRecentAccounts();
    Test.stopTest();

    // Then — verify required fields are populated on each record
    Assert.isFalse(result.isEmpty(), 'Result list should not be empty');
    Account first = result[0];
    Assert.isNotNull(first.Id, 'Id should be populated');
    Assert.isNotNull(first.Name, 'Name should be populated');
    Assert.isNotNull(first.CreatedDate, 'CreatedDate should be populated');
  }

  @IsTest
  static void shouldReturnEmptyList_WhenNoAccountsExist() {
    // Given — delete all accounts so org has none
    delete [SELECT Id FROM Account];

    // When
    Test.startTest();
    List<Account> result = AccountController.getRecentAccounts();
    Test.stopTest();

    // Then
    Assert.areEqual(
      0,
      result.size(),
      'Should return empty list when no accounts exist'
    );
  }

  @IsTest
  static void shouldReturnAllAccounts_WhenFewerThan10Exist() {
    // Given — delete all but 3 accounts
    List<Account> allAccounts = [
      SELECT Id
      FROM Account
      ORDER BY CreatedDate DESC
    ];
    List<Account> toDelete = new List<Account>();
    for (Integer i = 3; i < allAccounts.size(); i++) {
      toDelete.add(allAccounts[i]);
    }
    delete toDelete;

    // When
    Test.startTest();
    List<Account> result = AccountController.getRecentAccounts();
    Test.stopTest();

    // Then
    Assert.areEqual(
      3,
      result.size(),
      'Should return all 3 accounts when fewer than 10 exist'
    );
  }
}
