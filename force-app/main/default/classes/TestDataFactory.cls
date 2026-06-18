/**
 * Centralised factory for creating test SObject records.
 * All test classes must use this factory — never build records inline.
 */
@IsTest
public class TestDataFactory {
  /**
   * Creates Account records and optionally inserts them.
   *
   * @param count  Number of Account records to create
   * @param doInsert  When true, inserts the records before returning
   * @return List of Account records
   * @example
   * List<Account> accounts = TestDataFactory.createAccounts(10, true);
   */
  public static List<Account> createAccounts(Integer count, Boolean doInsert) {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      accounts.add(
        new Account(
          Name = 'Test Account ' + i,
          Industry = 'Technology',
          Phone = '555-000-' + String.valueOf(i).leftPad(4, '0')
        )
      );
    }
    if (doInsert) {
      insert accounts;
    }
    return accounts;
  }
}
