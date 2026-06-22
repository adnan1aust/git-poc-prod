/**
 * AuraEnabled controller providing Lead data for Lightning components.
 * Exposes the 10 most recently created Leads and Lead detail retrieval by Id.
 */
public with sharing class LeadController {
  /**
   * Returns the 10 most recently created Lead records ordered by creation date descending.
   *
   * @return List of up to 10 Lead records with key fields for list display
   * @example
   * List<Lead> leads = LeadController.getRecentLeads();
   */
  @AuraEnabled(cacheable=true)
  public static List<Lead> getRecentLeads() {
    return [
      SELECT
        Id,
        FirstName,
        LastName,
        Name,
        Company,
        Status,
        Email,
        Phone,
        LeadSource,
        CreatedDate
      FROM Lead
      WITH USER_MODE
      ORDER BY CreatedDate DESC
      LIMIT 10
    ];
  }

  /**
   * Returns a single Lead record by its Id.
   *
   * @param leadId The Id of the Lead to retrieve
   * @return The matching Lead record
   * @throws AuraHandledException if leadId is null or the Lead is not found
   * @example
   * Lead lead = LeadController.getLeadById('00Q000000000001AAA');
   */
  @AuraEnabled(cacheable=true)
  public static Lead getLeadById(Id leadId) {
    if (leadId == null) {
      throw new AuraHandledException('Lead Id must not be null.');
    }
    List<Lead> leads = [
      SELECT
        Id,
        FirstName,
        LastName,
        Name,
        Company,
        Status,
        Email,
        Phone,
        LeadSource,
        Rating,
        Industry,
        Street,
        City,
        State,
        PostalCode,
        Country,
        NumberOfEmployees,
        AnnualRevenue,
        Description,
        ConvertedDate,
        IsConverted,
        OwnerId,
        CreatedDate
      FROM Lead
      WHERE Id = :leadId
      WITH USER_MODE
      LIMIT 1
    ];
    if (leads.isEmpty()) {
      throw new AuraHandledException('Lead not found for Id: ' + leadId);
    }
    return leads[0];
  }
}
