@IsTest
private class CustomerSegmentServiceTest {
  @IsTest
  static void picksSegmentByRevenue() {
    Assert.areEqual('Enterprise', CustomerSegmentService.segmentFor(80000000));
    Assert.areEqual('Mid-Market', CustomerSegmentService.segmentFor(5000000));
    Assert.areEqual('Small Business', CustomerSegmentService.segmentFor(1000));
  }

  @IsTest
  static void treatsBlankRevenueAsSmallBusiness() {
    Assert.areEqual('Small Business', CustomerSegmentService.segmentFor(null));
  }
}
