@IsTest
private class DemoGreetingServiceTest {
    @IsTest
    static void greetsByName() {
        Assert.areEqual('Hello from the pipeline, Ana!', DemoGreetingService.greet('Ana'));
    }

    @IsTest
    static void greetsTeamWhenBlank() {
        Assert.areEqual('Hello from the pipeline, team!', DemoGreetingService.greet(''));
    }

    @IsTest
    static void greetsByTier() {
        Assert.areEqual('Hello from the pipeline, Gold customer!', DemoGreetingService.greetTier('Gold'));
        Assert.areEqual('Hello from the pipeline, team!', DemoGreetingService.greetTier(null));
    }
}
