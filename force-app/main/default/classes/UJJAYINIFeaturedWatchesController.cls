public with sharing class UJJAYINIFeaturedWatchesController {

    public class FeaturedWatch {

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String imageUrl;

        @AuraEnabled
        public String brand;

        @AuraEnabled
        public String collection;

        @AuraEnabled
        public String movement;

        @AuraEnabled
        public String caseMaterial;

        @AuraEnabled
        public String dialColor;

        @AuraEnabled
        public String modelNumber;

        @AuraEnabled
        public String productCode;
    }


    @AuraEnabled(cacheable=true)
    public static List<FeaturedWatch> getFeaturedWatches() {

        List<Product2> products = [
            SELECT
                Id,
                Name,
                Product_Image_URL__c,
                Brand__c,
                Collection__c,
                Movement_Type__c,
                Case_Material__c,
                Dial_Color__c,
                Model_Number__c,
                ProductCode
            FROM Product2
            WHERE IsActive = true
            AND Product_Image_URL__c != null
            ORDER BY CreatedDate DESC
            LIMIT 3
        ];

        List<FeaturedWatch> results =
            new List<FeaturedWatch>();

        for (Product2 product : products) {

            FeaturedWatch watch =
                new FeaturedWatch();

            watch.productId =
                product.Id;

            watch.name =
                product.Name;

            watch.imageUrl =
                product.Product_Image_URL__c;

            watch.brand =
                product.Brand__c;

            watch.collection =
                product.Collection__c;

            watch.movement =
                product.Movement_Type__c;

            watch.caseMaterial =
                product.Case_Material__c;

            watch.dialColor =
                product.Dial_Color__c;

            watch.modelNumber =
                product.Model_Number__c;

            watch.productCode =
                product.ProductCode;

            results.add(watch);
        }

        return results;
    }
}