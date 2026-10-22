@IsTest
private class LegacyDiscountCalculatorTest {
  @IsTest
  static void appliesFivePercent() {
    Assert.areEqual(5, LegacyDiscountCalculator.discountFor(100));
  }

  @IsTest
  static void returnsZeroWithoutAmount() {
    Assert.areEqual(0, LegacyDiscountCalculator.discountFor(null));
  }
}
