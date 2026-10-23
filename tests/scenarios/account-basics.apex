// Scenario: a new Account can be saved and found again.
// Runs as anonymous Apex against the deployed org; everything is rolled back at the end.
Savepoint sp = Database.setSavepoint();
try {
    Account acc = new Account(Name = 'REGTEST Account basics');
    insert acc;

    Account saved = [SELECT Id, Name FROM Account WHERE Id = :acc.Id];
    Assert.areEqual('REGTEST Account basics', saved.Name, 'The Account was not saved');
} finally {
    Database.rollback(sp);
}
