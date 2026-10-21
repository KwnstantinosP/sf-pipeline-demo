public with sharing class DemoGreetingService {
    /**
     * @description Builds a greeting for the given name.
     * @param name Person to greet; blank greets the team
     * @return The greeting text
     */
    public static String greet(String name) {
        return 'Hello from the pipeline, ' + (String.isBlank(name) ? 'team' : name) + '!';
    }

    /**
     * @description Builds a greeting for the Account's demo tier.
     * @param tier Value of Account.Pipeline_Demo_Tier__c
     * @return The greeting text
     */
    public static String greetTier(String tier) {
        return greet(String.isBlank(tier) ? null : tier.trim() + ' customer');
    }

    /**
     * @description Builds a greeting for an Account, using its demo tier when set.
     * @param acc Account with Name and Pipeline_Demo_Tier__c
     * @return The greeting text
     */
    public static String greetAccount(Account acc) {
        if (acc == null) {
            return greet(null);
        }
        return String.isBlank(acc.Pipeline_Demo_Tier__c) ? greet(acc.Name) : greetTier(acc.Pipeline_Demo_Tier__c);
    }
}
