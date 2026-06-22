@IsTest
private class LeadControllerTest {
  private static final Integer LEAD_COUNT = 15;

  @TestSetup
  static void setupTestData() {
    TestDataFactory.createLeads(LEAD_COUNT, true);
  }

  // ─── getRecentLeads ───────────────────────────────────────────────────────

  @IsTest
  static void getRecentLeads_ReturnsAtMostTen() {
    // When
    Test.startTest();
    List<Lead> result = LeadController.getRecentLeads();
    Test.stopTest();

    // Then
    Assert.areEqual(
      10,
      result.size(),
      'Should return exactly 10 leads regardless of total count'
    );
  }

  @IsTest
  static void getRecentLeads_OrderedByCreatedDateDescending() {
    // When
    Test.startTest();
    List<Lead> result = LeadController.getRecentLeads();
    Test.stopTest();

    // Then
    Assert.isFalse(result.isEmpty(), 'Result should not be empty');
    for (Integer i = 0; i < result.size() - 1; i++) {
      Assert.isTrue(
        result[i].CreatedDate >= result[i + 1].CreatedDate,
        'Leads should be ordered newest first at index ' + i
      );
    }
  }

  @IsTest
  static void getRecentLeads_ContainsRequiredFields() {
    // When
    Test.startTest();
    List<Lead> result = LeadController.getRecentLeads();
    Test.stopTest();

    // Then — spot-check first record for all expected fields
    Assert.isFalse(result.isEmpty(), 'Result should not be empty');
    Lead first = result[0];
    Assert.isNotNull(first.Id, 'Id should be populated');
    Assert.isNotNull(first.LastName, 'LastName should be populated');
    Assert.isNotNull(first.Company, 'Company should be populated');
    Assert.isNotNull(first.Status, 'Status should be populated');
    Assert.isNotNull(first.CreatedDate, 'CreatedDate should be populated');
  }

  @IsTest
  static void getRecentLeads_ReturnsEmptyList_WhenNoLeads() {
    // Given — delete all leads created in @TestSetup
    delete [SELECT Id FROM Lead];

    // When
    Test.startTest();
    List<Lead> result = LeadController.getRecentLeads();
    Test.stopTest();

    // Then
    Assert.areEqual(
      0,
      result.size(),
      'Should return empty list when no leads exist'
    );
  }

  // ─── getLeadById ─────────────────────────────────────────────────────────

  @IsTest
  static void getLeadById_ReturnsCorrectLead() {
    // Given
    Lead existing = [SELECT Id, FirstName, LastName, Company FROM Lead LIMIT 1];

    // When
    Test.startTest();
    Lead result = LeadController.getLeadById(existing.Id);
    Test.stopTest();

    // Then
    Assert.areEqual(
      existing.Id,
      result.Id,
      'Returned Lead Id should match the requested Id'
    );
    Assert.areEqual(
      existing.LastName,
      result.LastName,
      'LastName should match'
    );
    Assert.areEqual(existing.Company, result.Company, 'Company should match');
  }

  @IsTest
  static void getLeadById_ContainsDetailFields() {
    // Given
    Lead existing = [SELECT Id FROM Lead LIMIT 1];

    // When
    Test.startTest();
    Lead result = LeadController.getLeadById(existing.Id);
    Test.stopTest();

    // Then — verify detail-specific fields are returned
    Assert.isNotNull(result.Email, 'Email should be populated');
    Assert.isNotNull(result.Phone, 'Phone should be populated');
    Assert.isNotNull(result.LeadSource, 'LeadSource should be populated');
    Assert.isNotNull(result.OwnerId, 'OwnerId should be populated');
  }

  @IsTest
  static void getLeadById_ThrowsAuraHandledException_WhenNullId() {
    // When / Then
    Test.startTest();
    try {
      LeadController.getLeadById(null);
      Assert.fail('Expected AuraHandledException for null Id');
    } catch (AuraHandledException e) {
      // AuraHandledException.getMessage() always returns "Script-thrown exception"
      // on the platform — catching the right exception type is sufficient
    }
    Test.stopTest();
  }

  @IsTest
  static void getLeadById_ThrowsAuraHandledException_WhenLeadNotFound() {
    // Given — a well-formed but non-existent Lead Id
    Id nonExistentId = '00Q000000000001AAA';

    // When / Then
    Test.startTest();
    try {
      LeadController.getLeadById(nonExistentId);
      Assert.fail('Expected AuraHandledException for non-existent Lead Id');
    } catch (AuraHandledException e) {
      // AuraHandledException.getMessage() always returns "Script-thrown exception"
      // on the platform — catching the right exception type is sufficient
    }
    Test.stopTest();
  }
}
