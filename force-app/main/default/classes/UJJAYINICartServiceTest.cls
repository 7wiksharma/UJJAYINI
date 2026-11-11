@IsTest
private class UJJAYINICartServiceTest {


    // =========================================================
    // CREATE TEST ACCOUNT + CONTACT
    // =========================================================

    private static Contact createTestContact() {

        Account account = new Account(
            Name = 'UJJAYINI Test Account'
        );

        insert account;


        Contact contact = new Contact(
            FirstName = 'UJJAYINI',
            LastName = 'Test Customer',
            AccountId = account.Id
        );

        insert contact;


        return contact;
    }


    // =========================================================
    // CREATE TEST PRODUCT
    // =========================================================

    private static Product2 createTestProduct(
        String productName,
        String productCode
    ) {

        Product2 product = new Product2(
            Name = productName,
            ProductCode = productCode,
            IsActive = true
        );

        insert product;


        return product;
    }


    // =========================================================
    // CREATE STANDARD PRICEBOOK ENTRY
    // =========================================================

    private static PricebookEntry createStandardPricebookEntry(
        Id productId,
        Decimal price
    ) {

        Id standardPricebookId =
            Test.getStandardPricebookId();


        UJJAYINICartService.testStandardPricebookId =
            standardPricebookId;


        PricebookEntry pricebookEntry =
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = productId,
                UnitPrice = price,
                IsActive = true
            );

        insert pricebookEntry;


        return pricebookEntry;
    }


    // =========================================================
    // TEST 1
    // ADD PRODUCT TO CART
    // =========================================================

    @IsTest
    static void testAddToCartCreatesDraftOrder() {

        Contact contact =
            createTestContact();


        UJJAYINICartService.testContactId =
            contact.Id;


        Product2 product =
            createTestProduct(
                'UJJAYINI Test Chronograph',
                'UJ-TEST-001'
            );


        createStandardPricebookEntry(
            product.Id,
            50000
        );


        Test.startTest();


        UJJAYINICartService.CartResult result =
            UJJAYINICartService.addToCart(
                product.Id,
                1
            );


        Test.stopTest();


        System.assertNotEquals(
            null,
            result,
            'Cart result should not be null.'
        );


        System.assertNotEquals(
            null,
            result.orderId,
            'Draft Order should be created.'
        );


        System.assertEquals(
            'Draft',
            result.status,
            'Cart should be Draft.'
        );


        System.assertEquals(
            1,
            result.items.size(),
            'Cart should contain one item.'
        );


        System.assertEquals(
            product.Id,
            result.items[0].productId,
            'Product Id should match.'
        );


        System.assertEquals(
            1,
            result.items[0].quantity,
            'Quantity should be 1.'
        );


        System.assertEquals(
            50000,
            result.items[0].unitPrice,
            'Unit price should be 50000.'
        );


        System.assertEquals(
            50000,
            result.items[0].totalPrice,
            'Total price should be 50000.'
        );


        System.assertEquals(
            50000,
            result.totalAmount,
            'Cart total should be 50000.'
        );


        // -----------------------------------------------------
        // VERIFY ORDER
        // -----------------------------------------------------

        Order createdOrder = [
            SELECT Id,
                   AccountId,
                   Status,
                   Pricebook2Id
            FROM Order
            WHERE Id = :result.orderId
            LIMIT 1
        ];


        System.assertEquals(
            contact.AccountId,
            createdOrder.AccountId,
            'Order should belong to customer Account.'
        );


        System.assertEquals(
            'Draft',
            createdOrder.Status,
            'Order should be Draft.'
        );


        System.assertEquals(
            Test.getStandardPricebookId(),
            createdOrder.Pricebook2Id,
            'Order should use Standard Pricebook.'
        );


        // -----------------------------------------------------
        // VERIFY ORDER ITEM
        // -----------------------------------------------------

        List<OrderItem> orderItems = [
            SELECT Id,
                   Product2Id,
                   Quantity,
                   UnitPrice,
                   TotalPrice
            FROM OrderItem
            WHERE OrderId = :result.orderId
        ];


        System.assertEquals(
            1,
            orderItems.size(),
            'Exactly one Order Item should exist.'
        );


        System.assertEquals(
            product.Id,
            orderItems[0].Product2Id,
            'Order Item should reference correct product.'
        );


        System.assertEquals(
            1,
            orderItems[0].Quantity,
            'Order Item quantity should be 1.'
        );
    }


    // =========================================================
    // TEST 2
    // ADD SAME PRODUCT AGAIN
    // =========================================================

    @IsTest
    static void testAddingSameProductIncreasesQuantity() {

        Contact contact =
            createTestContact();


        UJJAYINICartService.testContactId =
            contact.Id;


        Product2 product =
            createTestProduct(
                'UJJAYINI Test Heritage',
                'UJ-TEST-002'
            );


        createStandardPricebookEntry(
            product.Id,
            70000
        );


        Test.startTest();


        UJJAYINICartService.CartResult firstResult =
            UJJAYINICartService.addToCart(
                product.Id,
                1
            );


        UJJAYINICartService.CartResult secondResult =
            UJJAYINICartService.addToCart(
                product.Id,
                2
            );


        Test.stopTest();


        System.assertEquals(
            firstResult.orderId,
            secondResult.orderId,
            'Both additions should use the same Draft Order.'
        );


        System.assertEquals(
            1,
            secondResult.items.size(),
            'Same product should not create duplicate item.'
        );


        System.assertEquals(
            3,
            secondResult.items[0].quantity,
            'Quantity should become 3.'
        );


        System.assertEquals(
            70000,
            secondResult.items[0].unitPrice,
            'Unit price should remain 70000.'
        );


        System.assertEquals(
            210000,
            secondResult.items[0].totalPrice,
            'Total should be 210000.'
        );


        System.assertEquals(
            210000,
            secondResult.totalAmount,
            'Cart total should be 210000.'
        );


        // -----------------------------------------------------
        // DATABASE CHECK
        // -----------------------------------------------------

        List<OrderItem> orderItems = [
            SELECT Id,
                   Quantity,
                   Product2Id,
                   UnitPrice,
                   TotalPrice
            FROM OrderItem
            WHERE OrderId = :secondResult.orderId
        ];


        System.assertEquals(
            1,
            orderItems.size(),
            'Only one Order Item should exist.'
        );


        System.assertEquals(
            3,
            orderItems[0].Quantity,
            'Database quantity should be 3.'
        );


        System.assertEquals(
            70000,
            orderItems[0].UnitPrice,
            'Database unit price should be 70000.'
        );


        System.assertEquals(
            210000,
            orderItems[0].TotalPrice,
            'Database total should be 210000.'
        );
    }


    // =========================================================
    // TEST 3
    // GET CURRENT CART
    // =========================================================

    @IsTest
    static void testGetCurrentCart() {

        Contact contact =
            createTestContact();


        UJJAYINICartService.testContactId =
            contact.Id;


        Product2 product =
            createTestProduct(
                'UJJAYINI Test Diver',
                'UJ-TEST-003'
            );


        createStandardPricebookEntry(
            product.Id,
            60000
        );


        Test.startTest();


        UJJAYINICartService.CartResult addResult =
            UJJAYINICartService.addToCart(
                product.Id,
                2
            );


        UJJAYINICartService.CartResult cartResult =
            UJJAYINICartService.getCurrentCart();


        Test.stopTest();


        System.assertEquals(
            addResult.orderId,
            cartResult.orderId,
            'Current cart should return same Draft Order.'
        );


        System.assertEquals(
            'Draft',
            cartResult.status,
            'Current cart should be Draft.'
        );


        System.assertEquals(
            1,
            cartResult.items.size(),
            'Current cart should contain one item.'
        );


        System.assertEquals(
            product.Id,
            cartResult.items[0].productId,
            'Product should match.'
        );


        System.assertEquals(
            2,
            cartResult.items[0].quantity,
            'Quantity should be 2.'
        );


        System.assertEquals(
            60000,
            cartResult.items[0].unitPrice,
            'Unit price should be 60000.'
        );


        System.assertEquals(
            120000,
            cartResult.items[0].totalPrice,
            'Total should be 120000.'
        );


        System.assertEquals(
            120000,
            cartResult.totalAmount,
            'Cart total should be 120000.'
        );
    }


    // =========================================================
    // TEST 4
    // EMPTY CART
    // =========================================================

    @IsTest
    static void testGetCurrentCartWhenEmpty() {

        Contact contact =
            createTestContact();


        UJJAYINICartService.testContactId =
            contact.Id;


        Test.startTest();


        UJJAYINICartService.CartResult result =
            UJJAYINICartService.getCurrentCart();


        Test.stopTest();


        System.assertNotEquals(
            null,
            result,
            'Result should not be null.'
        );


        System.assertEquals(
            null,
            result.orderId,
            'Empty cart should not have Order Id.'
        );


        System.assertEquals(
            'EMPTY',
            result.status,
            'Cart status should be EMPTY.'
        );


        System.assertEquals(
            0,
            result.totalAmount,
            'Empty cart total should be zero.'
        );


        System.assertEquals(
            0,
            result.items.size(),
            'Empty cart should contain no items.'
        );
    }


    // =========================================================
    // TEST 5
    // DECREASE QUANTITY
    // =========================================================

    @IsTest
    static void testDecreaseQuantity() {

        Contact contact =
            createTestContact();


        UJJAYINICartService.testContactId =
            contact.Id;


        Product2 product =
            createTestProduct(
                'UJJAYINI Test Decrease',
                'UJ-TEST-005'
            );


        createStandardPricebookEntry(
            product.Id,
            50000
        );


        UJJAYINICartService.addToCart(
            product.Id,
            3
        );


        Test.startTest();


        UJJAYINICartService.CartResult result =
            UJJAYINICartService.decreaseQuantity(
                product.Id
            );


        Test.stopTest();


        System.assertEquals(
            2,
            result.items[0].quantity,
            'Quantity should decrease from 3 to 2.'
        );
    }


    // =========================================================
    // TEST 6
    // DECREASE FROM ONE REMOVES ITEM
    // =========================================================

    @IsTest
    static void testDecreaseQuantityAtOneRemovesItem() {

        Contact contact =
            createTestContact();


        UJJAYINICartService.testContactId =
            contact.Id;


        Product2 product =
            createTestProduct(
                'UJJAYINI Test Remove By Decrease',
                'UJ-TEST-006'
            );


        createStandardPricebookEntry(
            product.Id,
            50000
        );


        UJJAYINICartService.addToCart(
            product.Id,
            1
        );


        Test.startTest();


        UJJAYINICartService.CartResult result =
            UJJAYINICartService.decreaseQuantity(
                product.Id
            );


        Test.stopTest();


        System.assertEquals(
            0,
            result.items.size(),
            'Item should be removed when quantity reaches zero.'
        );
    }


    // =========================================================
    // TEST 7
    // REMOVE FROM CART
    // =========================================================

    @IsTest
    static void testRemoveFromCart() {

        Contact contact =
            createTestContact();


        UJJAYINICartService.testContactId =
            contact.Id;


        Product2 product =
            createTestProduct(
                'UJJAYINI Test Remove',
                'UJ-TEST-007'
            );


        createStandardPricebookEntry(
            product.Id,
            50000
        );


        UJJAYINICartService.addToCart(
            product.Id,
            2
        );


        Test.startTest();


        UJJAYINICartService.CartResult result =
            UJJAYINICartService.removeFromCart(
                product.Id
            );


        Test.stopTest();


        System.assertEquals(
            0,
            result.items.size(),
            'Product should be removed from cart.'
        );
    }
}