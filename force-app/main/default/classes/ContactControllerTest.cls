@IsTest
private class ContactControllerTest {
  private static final Integer CONTACT_COUNT = 15;

  @TestSetup
  static void setupTestData() {
    TestDataFactory.createContacts(CONTACT_COUNT, true);
  }

  // ─── getRecentContacts ────────────────────────────────────────────────────

  @IsTest
  static void getRecentContacts_ReturnsAtMostTen() {
    // When
    Test.startTest();
    List<Contact> result = ContactController.getRecentContacts();
    Test.stopTest();

    // Then
    Assert.areEqual(
      10,
      result.size(),
      'Should return exactly 10 contacts regardless of total count'
    );
  }

  @IsTest
  static void getRecentContacts_OrderedByCreatedDateDescending() {
    // When
    Test.startTest();
    List<Contact> result = ContactController.getRecentContacts();
    Test.stopTest();

    // Then
    Assert.isFalse(result.isEmpty(), 'Result should not be empty');
    for (Integer i = 0; i < result.size() - 1; i++) {
      Assert.isTrue(
        result[i].CreatedDate >= result[i + 1].CreatedDate,
        'Contacts should be ordered newest first at index ' + i
      );
    }
  }

  @IsTest
  static void getRecentContacts_ContainsRequiredFields() {
    // When
    Test.startTest();
    List<Contact> result = ContactController.getRecentContacts();
    Test.stopTest();

    // Then — spot-check first record for all expected fields
    Assert.isFalse(result.isEmpty(), 'Result should not be empty');
    Contact first = result[0];
    Assert.isNotNull(first.Id, 'Id should be populated');
    Assert.isNotNull(first.LastName, 'LastName should be populated');
    Assert.isNotNull(first.Email, 'Email should be populated');
    Assert.isNotNull(first.CreatedDate, 'CreatedDate should be populated');
  }

  @IsTest
  static void getRecentContacts_ReturnsEmptyList_WhenNoContacts() {
    // Given — delete all contacts created in @TestSetup
    delete [SELECT Id FROM Contact];

    // When
    Test.startTest();
    List<Contact> result = ContactController.getRecentContacts();
    Test.stopTest();

    // Then
    Assert.areEqual(
      0,
      result.size(),
      'Should return empty list when no contacts exist'
    );
  }

  // ─── getContactById ───────────────────────────────────────────────────────

  @IsTest
  static void getContactById_ReturnsCorrectContact() {
    // Given
    Contact existing = [
      SELECT Id, FirstName, LastName, Email
      FROM Contact
      LIMIT 1
    ];

    // When
    Test.startTest();
    Contact result = ContactController.getContactById(existing.Id);
    Test.stopTest();

    // Then
    Assert.areEqual(
      existing.Id,
      result.Id,
      'Returned Contact Id should match the requested Id'
    );
    Assert.areEqual(
      existing.LastName,
      result.LastName,
      'LastName should match'
    );
    Assert.areEqual(existing.Email, result.Email, 'Email should match');
  }

  @IsTest
  static void getContactById_ContainsDetailFields() {
    // Given
    Contact existing = [SELECT Id FROM Contact LIMIT 1];

    // When
    Test.startTest();
    Contact result = ContactController.getContactById(existing.Id);
    Test.stopTest();

    // Then — verify detail-specific fields are returned
    Assert.isNotNull(result.Email, 'Email should be populated');
    Assert.isNotNull(result.Phone, 'Phone should be populated');
    Assert.isNotNull(result.LeadSource, 'LeadSource should be populated');
    Assert.isNotNull(result.OwnerId, 'OwnerId should be populated');
  }

  @IsTest
  static void getContactById_ThrowsAuraHandledException_WhenNullId() {
    // When / Then
    Test.startTest();
    try {
      ContactController.getContactById(null);
      Assert.fail('Expected AuraHandledException for null Id');
    } catch (AuraHandledException e) {
      // AuraHandledException.getMessage() always returns "Script-thrown exception"
      // on the platform — catching the right exception type is sufficient
    }
    Test.stopTest();
  }

  @IsTest
  static void getContactById_ThrowsAuraHandledException_WhenContactNotFound() {
    // Given — a well-formed but non-existent Contact Id
    Id nonExistentId = '003000000000001AAA';

    // When / Then
    Test.startTest();
    try {
      ContactController.getContactById(nonExistentId);
      Assert.fail('Expected AuraHandledException for non-existent Contact Id');
    } catch (AuraHandledException e) {
      // AuraHandledException.getMessage() always returns "Script-thrown exception"
      // on the platform — catching the right exception type is sufficient
    }
    Test.stopTest();
  }
}
