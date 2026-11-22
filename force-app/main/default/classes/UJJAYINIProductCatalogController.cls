public without sharing class UJJAYINIProductCatalogController {

    /*
     * A timepiece is shown as "low stock" when this many units
     * (or fewer) are still available.
     */
    @TestVisible
    private static final Integer LOW_STOCK_THRESHOLD = 2;


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

        // Extra specifications (Watches page filters + compare)
        @AuraEnabled public String brand;
        @AuraEnabled public String strapMaterial;
        @AuraEnabled public String waterResistance;
        @AuraEnabled public Boolean limitedEdition;
        @AuraEnabled public Integer editionSize;
        @AuraEnabled public Integer warrantyMonths;

        // Stock: IN_STOCK, LOW_STOCK or OUT_OF_STOCK
        @AuraEnabled public String stockStatus;

        // Only meaningful for LOW_STOCK. The exact stock of a
        // product that is comfortably in stock is never exposed.
        @AuraEnabled public Integer availableQuantity;


        public ProductWrapper(
            Product2 product,
            Decimal priceValue
        ) {

            productId       = product.Id;
            productName     = product.Name;
            productCode     = product.ProductCode;
            description     = product.Description;
            family          = product.Family;
            productImageUrl = product.Product_Image_URL__c;
            price           = priceValue;

            collectionName =
                product.Collection__r != null
                    ? product.Collection__r.Name
                    : null;

            // Product detail specifications
            movement     = product.Movement_Type__c;
            caseMaterial = product.Case_Material__c;
            dialColor    = product.Dial_Color__c;
            modelNumber  = product.Model_Number__c;

            // Read generically so the code works whether these
            // fields are Text, Picklist or Number.
            brand           = text(product.get('Brand__c'));
            strapMaterial   = text(product.get('Strap_Material__c'));
            waterResistance = text(product.get('Water_Resistance__c'));
            limitedEdition  = product.get('Limited_Edition__c') == true;
            editionSize     = whole(product.get('Edition_Size__c'));
            warrantyMonths  = whole(product.get('Warranty_Period__c'));
        }
    }



    // =========================================================
    // GET ALL PRODUCTS
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getProducts() {

        List<ProductWrapper> products =
            new List<ProductWrapper>();

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
                Movement_Type__c,
                Case_Material__c,
                Dial_Color__c,
                Model_Number__c,
                Brand__c,
                Strap_Material__c,
                Water_Resistance__c,
                Limited_Edition__c,
                Edition_Size__c,
                Warranty_Period__c
            FROM Product2
            WHERE IsActive = true
            WITH SYSTEM_MODE
            ORDER BY Name
        ];

        Set<Id> productIds = new Set<Id>();

        for (Product2 product : productRecords) {
            productIds.add(product.Id);
        }

        Map<Id, Decimal> productPrices =
            getPricesByProduct(productIds);

        Map<Id, Decimal> availability =
            getAvailabilityByProduct(productIds);

        for (Product2 product : productRecords) {

            ProductWrapper wrapper =
                new ProductWrapper(
                    product,
                    productPrices.get(product.Id)
                );

            applyStock(
                wrapper,
                availability.get(product.Id)
            );

            products.add(wrapper);
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
                Movement_Type__c,
                Case_Material__c,
                Dial_Color__c,
                Model_Number__c,
                Brand__c,
                Strap_Material__c,
                Water_Resistance__c,
                Limited_Edition__c,
                Edition_Size__c,
                Warranty_Period__c
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

        Product2 product = productRecords[0];

        Map<Id, Decimal> productPrices =
            getPricesByProduct(new Set<Id>{ product.Id });

        ProductWrapper wrapper =
            new ProductWrapper(
                product,
                productPrices.get(product.Id)
            );

        Map<Id, Decimal> availability =
            getAvailabilityByProduct(new Set<Id>{ product.Id });

        applyStock(
            wrapper,
            availability.get(product.Id)
        );

        return wrapper;
    }



    // =========================================================
    // PRICE HELPER
    // =========================================================

    private static Map<Id, Decimal> getPricesByProduct(
        Set<Id> productIds
    ) {

        Map<Id, Decimal> productPrices =
            new Map<Id, Decimal>();

        if (productIds == null || productIds.isEmpty()) {
            return productPrices;
        }

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

            if (!productPrices.containsKey(entry.Product2Id)) {
                productPrices.put(
                    entry.Product2Id,
                    entry.UnitPrice
                );
            }
        }

        return productPrices;
    }



    // =========================================================
    // STOCK HELPERS
    // =========================================================

    /*
     * Sum of Available__c over the Active inventory rows of each
     * product. A product with no Active inventory row is simply
     * absent from the map (and is treated as out of stock).
     */
    private static Map<Id, Decimal> getAvailabilityByProduct(
        Set<Id> productIds
    ) {

        Map<Id, Decimal> availability =
            new Map<Id, Decimal>();

        if (productIds == null || productIds.isEmpty()) {
            return availability;
        }

        for (Inventory__c inventory : [
            SELECT
                Product__c,
                Available__c
            FROM Inventory__c
            WHERE Product__c IN :productIds
            AND Inventory_Status__c = 'Active'
            WITH SYSTEM_MODE
        ]) {

            Decimal current = availability.get(inventory.Product__c);

            if (current == null) {
                current = 0;
            }

            Decimal available = inventory.Available__c;

            if (available == null) {
                available = 0;
            }

            availability.put(
                inventory.Product__c,
                current + available
            );
        }

        return availability;
    }


    private static void applyStock(
        ProductWrapper wrapper,
        Decimal available
    ) {

        if (available == null || available <= 0) {
            wrapper.stockStatus = 'OUT_OF_STOCK';
            wrapper.availableQuantity = 0;
            return;
        }

        if (available <= LOW_STOCK_THRESHOLD) {
            wrapper.stockStatus = 'LOW_STOCK';
            wrapper.availableQuantity = Integer.valueOf(available);
            return;
        }

        wrapper.stockStatus = 'IN_STOCK';
    }



    // =========================================================
    // VALUE HELPERS
    // =========================================================

    @TestVisible
    private static String text(Object value) {

        if (value == null) {
            return null;
        }

        String result = String.valueOf(value).trim();

        return String.isBlank(result) ? null : result;
    }


    @TestVisible
    private static Integer whole(Object value) {

        String raw = text(value);

        if (raw == null) {
            return null;
        }

        try {
            return Decimal.valueOf(raw.replaceAll('[^0-9.]', '')).intValue();
        } catch (Exception ignored) {
            return null;
        }
    }
}