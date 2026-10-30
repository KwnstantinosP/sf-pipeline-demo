// Scenario: setting an Account's annual revenue fills in its Customer Segment, and changing it moves the segment.
// Runs as anonymous Apex against the deployed org; everything is rolled back at the end.
Savepoint sp = Database.setSavepoint();
try {
    Account big = new Account(Name = 'REGTEST Segment big', AnnualRevenue = 80000000);
    Account small = new Account(Name = 'REGTEST Segment small', AnnualRevenue = 1000);
    insert new List<Account>{ big, small };

    Map<Id, Account> saved = new Map<Id, Account>(
        [SELECT Customer_Segment__c FROM Account WHERE Id IN :new List<Id>{ big.Id, small.Id }]
    );
    Assert.areEqual('Enterprise', saved.get(big.Id).Customer_Segment__c, 'A large Account should be Enterprise');
    Assert.areEqual('Small Business', saved.get(small.Id).Customer_Segment__c, 'A small Account should be Small Business');

    small.AnnualRevenue = 6000000;
    update small;
    Assert.areEqual(
        'Mid-Market',
        [SELECT Customer_Segment__c FROM Account WHERE Id = :small.Id].Customer_Segment__c,
        'Raising the revenue should move the Account to Mid-Market'
    );
} finally {
    Database.rollback(sp);
}
