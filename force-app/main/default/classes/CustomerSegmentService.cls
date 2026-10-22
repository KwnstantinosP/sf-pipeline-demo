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
}
