@IsTest
private class DemoGreetingServiceTest {
    @IsTest
    static void greetsByName() {
        Assert.areEqual('Hello, Ana!', DemoGreetingService.greet('Ana'));
    }

    @IsTest
    static void greetsTeamWhenBlank() {
        Assert.areEqual('Hello, team!', DemoGreetingService.greet(''));
    }
}
