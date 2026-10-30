@IsTest
private class AccountTriggerTest {
  @IsTest
  static void setsSegmentOnInsertAndWhenRevenueChanges() {
    Account acc = new Account(Name = 'Acme', AnnualRevenue = 80000000);
    insert acc;
    Assert.areEqual('Enterprise', segmentOf(acc.Id));

    acc.AnnualRevenue = 1000;
    update acc;
    Assert.areEqual('Small Business', segmentOf(acc.Id));
  }

  @IsTest
  static void keepsSegmentWhenRevenueIsUnchanged() {
    Account acc = new Account(Name = 'Acme', AnnualRevenue = 80000000);
    insert acc;
    acc.Customer_Segment__c = 'Mid-Market';
    update acc;
    Assert.areEqual('Mid-Market', segmentOf(acc.Id));
  }

  @IsTest
  static void handlesManyAccountsAtOnce() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 200; i++) {
      accounts.add(new Account(Name = 'Bulk ' + i, AnnualRevenue = 6000000));
    }
    insert accounts;
    Assert.areEqual(
      200,
      [SELECT COUNT() FROM Account WHERE Customer_Segment__c = 'Mid-Market']
    );
  }

  private static String segmentOf(Id accountId) {
    return [SELECT Customer_Segment__c FROM Account WHERE Id = :accountId]
    .Customer_Segment__c;
  }
}
