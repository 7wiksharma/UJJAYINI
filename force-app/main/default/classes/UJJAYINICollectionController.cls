/*
 * Public catalogue data (collections and their active watches).
 * Read in SYSTEM_MODE, like UJJAYINIProductCatalogController, so a
 * logged-in customer sees exactly what a guest sees, whatever the
 * record sharing on Collection__c / Product2 is for customers.
 */
public with sharing class UJJAYINICollectionController {

    /*
     * Collection data returned to the LWC
     */
    public class CollectionWrapper {

        @AuraEnabled public Id collectionId;
        @AuraEnabled public String name;
        @AuraEnabled public String heroImageUrl;
        @AuraEnabled public String description;
        @AuraEnabled public String shortDescription;
        @AuraEnabled public Decimal displayOrder;
        @AuraEnabled public List<WatchWrapper> watches;
    }

    /*
     * Watch data returned to the LWC
     */
    public class WatchWrapper {

        @AuraEnabled public Id productId;
        @AuraEnabled public String name;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public String brand;
        @AuraEnabled public String collection;
        @AuraEnabled public String movement;
        @AuraEnabled public String caseMaterial;
        @AuraEnabled public String dialColor;
        @AuraEnabled public String modelNumber;
        @AuraEnabled public String productCode;
    }


    /*
     * Returns all collections with their watches.
     */
    @AuraEnabled(cacheable=true)
    public static List<CollectionWrapper> getCollectionsWithWatches() {

        List<Collection__c> collections = [
            SELECT
                Id,
                Name,
                Hero_Image_URL__c,
                Description__c,
                Short_Description__c,
                Display_Order__c
            FROM Collection__c
            WITH SYSTEM_MODE
            ORDER BY Display_Order__c ASC, Name ASC
        ];

        /*
         * All active products that have a collection assigned.
         */
        List<Product2> products = [
            SELECT
                Id,
                Name,
                Product_Image_URL__c,
                Brand__c,
                Collection__c,
                Collection__r.Name,
                Movement_Type__c,
                Case_Material__c,
                Dial_Color__c,
                Model_Number__c,
                ProductCode
            FROM Product2
            WHERE IsActive = true
            AND Product_Image_URL__c != null
            AND Collection__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
        ];

        /*
         * Group products by collection.
         *
         * Product2.Collection__c is a lookup, so it holds the
         * Collection's Id (not its name). Grouping by name made
         * every collection's watch list empty.
         */
        Map<Id, List<WatchWrapper>> watchesByCollection =
            new Map<Id, List<WatchWrapper>>();

        for (Product2 product : products) {

            if (!watchesByCollection.containsKey(product.Collection__c)) {
                watchesByCollection.put(product.Collection__c, new List<WatchWrapper>());
            }

            WatchWrapper watch = new WatchWrapper();
            watch.productId = product.Id;
            watch.name = product.Name;
            watch.imageUrl = product.Product_Image_URL__c;
            watch.brand = product.Brand__c;
            watch.collection = product.Collection__r != null ? product.Collection__r.Name : null;
            watch.movement = product.Movement_Type__c;
            watch.caseMaterial = product.Case_Material__c;
            watch.dialColor = product.Dial_Color__c;
            watch.modelNumber = product.Model_Number__c;
            watch.productCode = product.ProductCode;

            watchesByCollection.get(product.Collection__c).add(watch);
        }

        /*
         * Build final response.
         */
        List<CollectionWrapper> results = new List<CollectionWrapper>();

        for (Collection__c collection : collections) {

            CollectionWrapper wrapper = new CollectionWrapper();

            wrapper.collectionId = collection.Id;
            wrapper.name = collection.Name;
            wrapper.heroImageUrl = collection.Hero_Image_URL__c;
            wrapper.description = collection.Description__c;
            wrapper.shortDescription = collection.Short_Description__c;
            wrapper.displayOrder = collection.Display_Order__c;
            wrapper.watches = watchesByCollection.containsKey(collection.Id)
                ? watchesByCollection.get(collection.Id)
                : new List<WatchWrapper>();

            results.add(wrapper);
        }

        return results;
    }
}