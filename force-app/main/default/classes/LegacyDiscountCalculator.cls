public with sharing class LegacyDiscountCalculator {
  /**
   * @description Flat 5% discount used before commercial terms existed.
   * @param amount Order amount
   * @return Discount amount; 0 when no amount is given
   */
  public static Decimal discountFor(Decimal amount) {
    return amount == null ? 0 : amount * 0.05;
  }
}
