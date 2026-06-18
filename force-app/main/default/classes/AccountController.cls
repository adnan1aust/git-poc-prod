/**
 * AuraEnabled controller providing Account data for Lightning components.
 * Returns the 10 most recently created Accounts for homepage display.
 */
public with sharing class AccountController {
  /**
   * Returns the 10 most recently created Accounts ordered by creation date descending.
   *
   * @return List of up to 10 Account records with Id, Name, Industry, Phone, and CreatedDate
   * @throws AuraHandledException if the query fails
   * @example
   * List<Account> accounts = AccountController.getRecentAccounts();
   */
  @AuraEnabled(cacheable=true)
  public static List<Account> getRecentAccounts() {
    return [
      SELECT Id, Name, Industry, Phone, CreatedDate
      FROM Account
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 10
    ];
  }
}
