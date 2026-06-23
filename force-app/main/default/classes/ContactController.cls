/**
 * AuraEnabled controller providing Contact data for Lightning components.
 * Exposes the 10 most recently created Contacts and Contact detail retrieval by Id.
 */
public with sharing class ContactController {
  /**
   * Returns the 10 most recently created Contact records ordered by creation date descending.
   *
   * @return List of up to 10 Contact records with key fields for list display
   * @example
   * List<Contact> contacts = ContactController.getRecentContacts();
   */
  @AuraEnabled(cacheable=true)
  public static List<Contact> getRecentContacts() {
    return [
      SELECT
        Id,
        FirstName,
        LastName,
        Name,
        AccountId,
        Title,
        Email,
        Phone,
        LeadSource,
        CreatedDate
      FROM Contact
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 10
    ];
  }

  /**
   * Returns a single Contact record by its Id.
   *
   * @param contactId The Id of the Contact to retrieve
   * @return The matching Contact record
   * @throws AuraHandledException if contactId is null or the Contact is not found
   * @example
   * Contact contact = ContactController.getContactById('003000000000001AAA');
   */
  @AuraEnabled(cacheable=true)
  public static Contact getContactById(Id contactId) {
    if (contactId == null) {
      throw new AuraHandledException('Contact Id must not be null.');
    }
    List<Contact> contacts = [
      SELECT
        Id,
        FirstName,
        LastName,
        Name,
        AccountId,
        Title,
        Email,
        Phone,
        LeadSource,
        Department,
        Birthdate,
        MailingStreet,
        MailingCity,
        MailingState,
        MailingPostalCode,
        MailingCountry,
        Description,
        OwnerId,
        CreatedDate
      FROM Contact
      WHERE Id = :contactId
      WITH USER_MODE
      LIMIT 1
    ];
    if (contacts.isEmpty()) {
      throw new AuraHandledException('Contact not found for Id: ' + contactId);
    }
    return contacts[0];
  }
}
