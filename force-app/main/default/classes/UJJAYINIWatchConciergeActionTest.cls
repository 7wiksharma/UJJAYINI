@IsTest
private class UJJAYINIWatchConciergeActionTest {

    @TestSetup
    static void setup() {

        Collection__c gold = new Collection__c(Name = 'Hiranya');
        insert gold;

        Product2 watch = new Product2(
            Name = 'Test Gold Diver',
            IsActive = true,
            Description = 'A gold diver for testing.',
            Collection__c = gold.Id,
            Product_Image_URL__c = 'https://example.com/watch.png'
        );
        insert watch;

        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = watch.Id,
            UnitPrice = 250000,
            IsActive = true
        );

        Inventory__c inventory = new Inventory__c();
        inventory.put('Product__c', watch.Id);
        inventory.put('On_Hand__c', 5);
        inventory.put('Reserved__c', 0);
        inventory.put('Inventory_Status__c', 'Active');
        insert inventory;
    }

    @IsTest
    static void findsWatchByCollectionPriceAndKeyword() {

        UJJAYINIWatchConciergeAction.Request request = new UJJAYINIWatchConciergeAction.Request();
        request.collection = 'Hiranya';
        request.maxPrice = 300000;
        request.keywords = 'gold diver';

        Test.startTest();
        List<UJJAYINIWatchConciergeAction.Response> responses =
            UJJAYINIWatchConciergeAction.findWatches(new List<UJJAYINIWatchConciergeAction.Request>{ request });
        Test.stopTest();

        System.assertEquals(1, responses[0].matchCount);
        System.assert(responses[0].watches.contains('Test Gold Diver'));
        System.assert(responses[0].watches.contains('INR'));
    }

    @IsTest
    static void returnsFriendlyMessageWhenNothingMatches() {

        UJJAYINIWatchConciergeAction.Request request = new UJJAYINIWatchConciergeAction.Request();
        request.maxPrice = 1000;

        List<UJJAYINIWatchConciergeAction.Response> responses =
            UJJAYINIWatchConciergeAction.findWatches(new List<UJJAYINIWatchConciergeAction.Request>{ request });

        System.assertEquals(0, responses[0].matchCount);
        System.assert(responses[0].watches.startsWith('No UJJAYINI watch'));
    }
}