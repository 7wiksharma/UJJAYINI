public with sharing class UJJAYINIProductCatalogController {

    public class ProductWrapper {
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String description;
        @AuraEnabled public String family;
        @AuraEnabled public String collectionName;
        @AuraEnabled public Decimal price;

        public ProductWrapper(Product2 product, Decimal priceValue) {
            productId = product.Id;
            productName = product.Name;
            productCode = product.ProductCode;
            description = product.Description;
            family = product.Family;
            collectionName = product.Collection__r != null
                ? product.Collection__r.Name
                : null;
            price = priceValue;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getProducts() {

        List<ProductWrapper> products = new List<ProductWrapper>();

        List<Product2> productRecords = [
            SELECT Id,
                   Name,
                   ProductCode,
                   Description,
                   Family,
                   Collection__c,
                   Collection__r.Name
            FROM Product2
            WHERE IsActive = true
            ORDER BY Name
        ];

        Set<Id> productIds = new Set<Id>();

        for (Product2 product : productRecords) {
            productIds.add(product.Id);
        }

        Map<Id, Decimal> productPrices = new Map<Id, Decimal>();

        if (!productIds.isEmpty()) {

            for (PricebookEntry entry : [
    SELECT Product2Id,
           UnitPrice
    FROM PricebookEntry
    WHERE Product2Id IN :productIds
    AND IsActive = true
    AND Pricebook2.IsActive = true
    AND Pricebook2.IsStandard = true
]) {
                if (!productPrices.containsKey(entry.Product2Id)) {
                    productPrices.put(
                        entry.Product2Id,
                        entry.UnitPrice
                    );
                }
            }
        }

        for (Product2 product : productRecords) {

            products.add(
                new ProductWrapper(
                    product,
                    productPrices.get(product.Id)
                )
            );
        }

        return products;
    }
}