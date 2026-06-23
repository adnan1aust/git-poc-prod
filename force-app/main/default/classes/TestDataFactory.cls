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

  /**
   * Creates Lead records and optionally inserts them.
   *
   * @param count     Number of Lead records to create
   * @param doInsert  When true, inserts the records before returning
   * @return List of Lead records
   * @example
   * List<Lead> leads = TestDataFactory.createLeads(10, true);
   */
  public static List<Lead> createLeads(Integer count, Boolean doInsert) {
    List<Lead> leads = new List<Lead>();
    for (Integer i = 0; i < count; i++) {
      leads.add(
        new Lead(
          FirstName = 'FirstName' + i,
          LastName = 'LastName' + i,
          Company = 'Test Company ' + i,
          Email = 'lead' + i + '@testfactory.com',
          Phone = '555-100-' + String.valueOf(i).leftPad(4, '0'),
          LeadSource = 'Web',
          Status = 'Open - Not Contacted'
        )
      );
    }
    if (doInsert) {
      insert leads;
    }
    return leads;
  }

  /**
   * Creates Contact records and optionally inserts them.
   *
   * @param count     Number of Contact records to create
   * @param doInsert  When true, inserts the records before returning
   * @return List of Contact records
   * @example
   * List<Contact> contacts = TestDataFactory.createContacts(10, true);
   */
  public static List<Contact> createContacts(Integer count, Boolean doInsert) {
    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < count; i++) {
      contacts.add(
        new Contact(
          FirstName = 'FirstName' + i,
          LastName = 'LastName' + i,
          Email = 'contact' + i + '@testfactory.com',
          Phone = '555-200-' + String.valueOf(i).leftPad(4, '0'),
          LeadSource = 'Web',
          Title = 'Title ' + i
        )
      );
    }
    if (doInsert) {
      insert contacts;
    }
    return contacts;
  }
}
