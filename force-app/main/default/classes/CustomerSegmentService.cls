public with sharing class CustomerSegmentService {
  /**
   * @description Picks the customer segment for an annual revenue.
   * @param annualRevenue Account annual revenue; blank counts as Small Business
   * @return Enterprise, Mid-Market or Small Business
   */
  public static String segmentFor(Decimal annualRevenue) {
    if (annualRevenue != null && annualRevenue >= 50000000) {
      return 'Enterprise';
    }
    if (annualRevenue != null && annualRevenue >= 5000000) {
      return 'Mid-Market';
    }
    return 'Small Business';
  }

  /**
   * @description Sets Customer_Segment__c on new Accounts and on Accounts whose annual revenue changed.
   * @param accounts Accounts being saved (Trigger.new)
   * @param oldById Previous versions by Id (Trigger.oldMap); null on insert
   */
  public static void assignSegments(
    List<Account> accounts,
    Map<Id, Account> oldById
  ) {
    for (Account acc : accounts) {
      Account old = oldById == null ? null : oldById.get(acc.Id);
      if (old == null || old.AnnualRevenue != acc.AnnualRevenue) {
        acc.Customer_Segment__c = segmentFor(acc.AnnualRevenue);
      }
    }
  }
}
