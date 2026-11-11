@IsTest
private class UJJAYINIProductCatalogControllerTest {

    @IsTest
    static void testGetProducts() {

        // Create Collection
        Collection__c collectionRecord = new Collection__c(
            Name = 'UJJAYINI Test Collection'
        );
        insert collectionRecord;


        // Create active Product
        Product2 product = new Product2(
            Name = 'UJJAYINI Test Watch',
            ProductCode = 'UJ-TEST-001',
            Description = 'Test watch for product catalog',
            Family = 'Watches',
            Collection__c = collectionRecord.Id,
            IsActive = true
        );
        insert product;


        // Get Standard Pricebook
        Id standardPricebookId =
            Test.getStandardPricebookId();


        // Activate Standard Pricebook
        Pricebook2 standardPricebook = new Pricebook2(
            Id = standardPricebookId,
            IsActive = true
        );

        update standardPricebook;


        // Create Standard Pricebook Entry
        PricebookEntry standardEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 50000,
            IsActive = true
        );

        insert standardEntry;


        // Verify Pricebook Entry
        PricebookEntry verifyEntry = [
            SELECT Id,
                   Product2Id,
                   UnitPrice,
                   IsActive,
                   Pricebook2Id,
                   Pricebook2.IsStandard,
                   Pricebook2.IsActive
            FROM PricebookEntry
            WHERE Id = :standardEntry.Id
            LIMIT 1
        ];


        System.assertEquals(
            product.Id,
            verifyEntry.Product2Id,
            'Pricebook Entry should belong to the test product.'
        );

        System.assertEquals(
            50000,
            verifyEntry.UnitPrice,
            'Test product price should be 50000.'
        );

        System.assertEquals(
            true,
            verifyEntry.IsActive,
            'Pricebook Entry should be active.'
        );

        System.assertEquals(
            true,
            verifyEntry.Pricebook2.IsStandard,
            'Pricebook should be the Standard Pricebook.'
        );

        System.assertEquals(
            true,
            verifyEntry.Pricebook2.IsActive,
            'Standard Pricebook should be active.'
        );


        // Execute Controller
        Test.startTest();

        List<UJJAYINIProductCatalogController.ProductWrapper> products =
            UJJAYINIProductCatalogController.getProducts();

        Test.stopTest();


        // Verify returned products
        System.assertEquals(
            1,
            products.size(),
            'Expected exactly one active product.'
        );


        UJJAYINIProductCatalogController.ProductWrapper result =
            products[0];


        System.assertEquals(
            product.Id,
            result.productId
        );

        System.assertEquals(
            'UJJAYINI Test Watch',
            result.productName
        );

        System.assertEquals(
            'UJ-TEST-001',
            result.productCode
        );

        System.assertEquals(
            'Test watch for product catalog',
            result.description
        );

        System.assertEquals(
            'Watches',
            result.family
        );

        System.assertEquals(
            'UJJAYINI Test Collection',
            result.collectionName
        );

        System.assertEquals(
            50000,
            result.price,
            'Controller should return the Standard Pricebook price.'
        );
    }


    @IsTest
    static void testInactiveProductIsExcluded() {

        // Create inactive product
        Product2 inactiveProduct = new Product2(
            Name = 'UJJAYINI Inactive Watch',
            ProductCode = 'UJ-INACTIVE-001',
            IsActive = false
        );

        insert inactiveProduct;


        // Execute Controller
        Test.startTest();

        List<UJJAYINIProductCatalogController.ProductWrapper> products =
            UJJAYINIProductCatalogController.getProducts();

        Test.stopTest();


        // Verify inactive product is not returned
        for (
            UJJAYINIProductCatalogController.ProductWrapper product :
            products
        ) {

            System.assertNotEquals(
                inactiveProduct.Id,
                product.productId,
                'Inactive products must not appear in the catalog.'
            );
        }
    }
}