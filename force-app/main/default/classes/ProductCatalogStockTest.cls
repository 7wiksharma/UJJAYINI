@IsTest
private class ProductCatalogStockTest {

    private static Product2 createProduct(String name) {

        Product2 product = new Product2(
            Name = name,
            IsActive = true
        );

        insert product;

        return product;
    }


    private static void createInventory(
        Id productId,
        Decimal onHand
    ) {

        insert new Inventory__c(
            Product__c = productId,
            On_Hand__c = onHand,
            Reserved__c = 0,
            Inventory_Status__c = 'Active'
        );
    }


    private static UJJAYINIProductCatalogController.ProductWrapper
        findProduct(Id productId) {

        for (
            UJJAYINIProductCatalogController.ProductWrapper wrapper :
                UJJAYINIProductCatalogController.getProducts()
        ) {
            if (wrapper.productId == productId) {
                return wrapper;
            }
        }

        return null;
    }


    @IsTest
    static void comfortableStockIsInStock() {

        Product2 product = createProduct('Stock Test Plenty');
        createInventory(product.Id, 10);

        UJJAYINIProductCatalogController.ProductWrapper wrapper =
            findProduct(product.Id);

        System.assertEquals('IN_STOCK', wrapper.stockStatus);
    }


    @IsTest
    static void twoOrFewerLeftIsLowStock() {

        Product2 product = createProduct('Stock Test Low');
        createInventory(product.Id, 2);

        UJJAYINIProductCatalogController.ProductWrapper wrapper =
            findProduct(product.Id);

        System.assertEquals('LOW_STOCK', wrapper.stockStatus);
        System.assertEquals(2, wrapper.availableQuantity);
    }


    @IsTest
    static void zeroStockIsOutOfStock() {

        Product2 product = createProduct('Stock Test Zero');
        createInventory(product.Id, 0);

        UJJAYINIProductCatalogController.ProductWrapper wrapper =
            findProduct(product.Id);

        System.assertEquals('OUT_OF_STOCK', wrapper.stockStatus);
    }


    @IsTest
    static void noInventoryRowIsOutOfStock() {

        Product2 product = createProduct('Stock Test Untracked');

        UJJAYINIProductCatalogController.ProductWrapper wrapper =
            UJJAYINIProductCatalogController.getProduct(product.Id);

        System.assertEquals('OUT_OF_STOCK', wrapper.stockStatus);
    }
}