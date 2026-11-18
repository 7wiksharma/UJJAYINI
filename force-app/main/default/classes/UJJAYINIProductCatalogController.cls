public without sharing class UJJAYINIProductCatalogController {

    public class ProductWrapper {

        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String description;
        @AuraEnabled public String family;
        @AuraEnabled public String collectionName;
        @AuraEnabled public String productImageUrl;
        @AuraEnabled public Decimal price;

        // Product detail specifications
        @AuraEnabled public String movement;
        @AuraEnabled public String caseMaterial;
        @AuraEnabled public String dialColor;
        @AuraEnabled public String modelNumber;


        public ProductWrapper(
            Product2 product,
            Decimal priceValue
        ) {

            productId =
                product.Id;

            productName =
                product.Name;

            productCode =
                product.ProductCode;

            description =
                product.Description;

            family =
                product.Family;

            collectionName =
                product.Collection__r != null
                    ? product.Collection__r.Name
                    : null;

            productImageUrl =
                product.Product_Image_URL__c;

            price =
                priceValue;


            // =====================================================
            // PRODUCT DETAIL SPECIFICATIONS
            // =====================================================

            movement =
                product.Movement_Type__c;

            caseMaterial =
                product.Case_Material__c;

            dialColor =
                product.Dial_Color__c;

            modelNumber =
                product.Model_Number__c;
        }
    }



    // =========================================================
    // GET ALL PRODUCTS
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getProducts() {

        List<ProductWrapper> products =
            new List<ProductWrapper>();


        // -----------------------------------------------------
        // GET ACTIVE PRODUCTS
        // -----------------------------------------------------

        List<Product2> productRecords = [

            SELECT
                Id,
                Name,
                ProductCode,
                Description,
                Family,
                Collection__c,
                Collection__r.Name,
                Product_Image_URL__c,

                // Product detail fields
                Movement_Type__c,
                Case_Material__c,
                Dial_Color__c,
                Model_Number__c

            FROM Product2

            WHERE IsActive = true

            WITH SYSTEM_MODE

            ORDER BY Name
        ];



        // -----------------------------------------------------
        // COLLECT PRODUCT IDS
        // -----------------------------------------------------

        Set<Id> productIds =
            new Set<Id>();


        for (Product2 product : productRecords) {

            productIds.add(
                product.Id
            );
        }



        // -----------------------------------------------------
        // GET STANDARD PRICEBOOK PRICES
        // -----------------------------------------------------

        Map<Id, Decimal> productPrices =
            new Map<Id, Decimal>();


        if (!productIds.isEmpty()) {

            for (PricebookEntry entry : [

                SELECT
                    Product2Id,
                    UnitPrice

                FROM PricebookEntry

                WHERE Product2Id IN :productIds

                AND IsActive = true

                AND Pricebook2.IsActive = true

                AND Pricebook2.IsStandard = true

                WITH SYSTEM_MODE

            ]) {

                if (
                    !productPrices.containsKey(
                        entry.Product2Id
                    )
                ) {

                    productPrices.put(
                        entry.Product2Id,
                        entry.UnitPrice
                    );
                }
            }
        }



        // -----------------------------------------------------
        // BUILD RESPONSE
        // -----------------------------------------------------

        for (Product2 product : productRecords) {

            products.add(
                new ProductWrapper(
                    product,
                    productPrices.get(
                        product.Id
                    )
                )
            );
        }


        return products;
    }



    // =========================================================
    // GET SINGLE PRODUCT
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static ProductWrapper getProduct(
        Id productId
    ) {

        if (productId == null) {

            throw new IllegalArgumentException(
                'Product Id is required.'
            );
        }



        List<Product2> productRecords = [

            SELECT
                Id,
                Name,
                ProductCode,
                Description,
                Family,
                Collection__c,
                Collection__r.Name,
                Product_Image_URL__c,

                // Product detail fields
                Movement_Type__c,
                Case_Material__c,
                Dial_Color__c,
                Model_Number__c

            FROM Product2

            WHERE Id = :productId

            AND IsActive = true

            WITH SYSTEM_MODE

            LIMIT 1
        ];



        if (productRecords.isEmpty()) {

            throw new IllegalArgumentException(
                'Product not found.'
            );
        }



        Product2 product =
            productRecords[0];



        // -----------------------------------------------------
        // GET PRICE
        // -----------------------------------------------------

        List<PricebookEntry> priceEntries = [

            SELECT
                Product2Id,
                UnitPrice

            FROM PricebookEntry

            WHERE Product2Id = :product.Id

            AND IsActive = true

            AND Pricebook2.IsActive = true

            AND Pricebook2.IsStandard = true

            WITH SYSTEM_MODE

            LIMIT 1
        ];



        Decimal priceValue =
            priceEntries.isEmpty()
                ? null
                : priceEntries[0].UnitPrice;



        return new ProductWrapper(
            product,
            priceValue
        );
    }
}