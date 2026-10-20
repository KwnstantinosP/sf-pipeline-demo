public with sharing class DemoGreetingService {
    /**
     * @description Builds a greeting for the given name.
     * @param name Person to greet; blank greets the team
     * @return The greeting text
     */
    public static String greet(String name) {
        return 'Hello, ' + (String.isBlank(name) ? 'team' : name) + '!';
    }
}
