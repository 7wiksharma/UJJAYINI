@IsTest
private class AssetFulfillmentServiceTest {

    @IsTest
    static void testCreateAssetsForActivatedOrder() {

        Account accountRecord = new Account(
            Name = 'UJJAYINI Test Customer'
        );
        insert accountRecord;

        Product2 product = new Product2(
            Name = 'UJJAYINI Test Watch',
            IsActive = true
        );
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry standardEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 10000,
            IsActive = true
        );
        insert standardEntry;

        Pricebook2 pricebook = new Pricebook2(
            Name = 'UJJAYINI Test Pricebook',
            IsActive = true
        );
        insert pricebook;

        PricebookEntry customEntry = new PricebookEntry(
            Pricebook2Id = pricebook.Id,
            Product2Id = product.Id,
            UnitPrice = 10000,
            IsActive = true
        );
        insert customEntry;

        Order orderRecord = new Order(
            AccountId = accountRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = pricebook.Id
        );
        insert orderRecord;

        OrderItem orderItem = new OrderItem(
            OrderId = orderRecord.Id,
            PricebookEntryId = customEntry.Id,
            Quantity = 1,
            UnitPrice = 10000
        );
        insert orderItem;

        orderRecord.Status = 'Activated';
        update orderRecord;

        Test.startTest();

        AssetFulfillmentService.FulfillmentResult result =
            AssetFulfillmentService.createAssetsForOrder(
                orderRecord.Id
            );

        Test.stopTest();

        System.assertEquals(
            'FULFILLED',
            result.status
        );

        System.assertEquals(
            orderRecord.Id,
            result.orderId
        );

        System.assertEquals(
            1,
            result.assetIds.size()
        );

        Asset createdAsset = [
            SELECT Id,
                   AccountId,
                   Product2Id,
                   Quantity,
                   Price,
                   PurchaseDate,
                   Status,
                   SerialNumber,
                   Description
            FROM Asset
            WHERE Id = :result.assetIds[0]
            LIMIT 1
        ];

        System.assertEquals(
            accountRecord.Id,
            createdAsset.AccountId
        );

        System.assertEquals(
            product.Id,
            createdAsset.Product2Id
        );

        System.assertEquals(
            1,
            createdAsset.Quantity
        );

        System.assertEquals(
            10000,
            createdAsset.Price
        );

        System.assertEquals(
            Date.today(),
            createdAsset.PurchaseDate
        );

        System.assertEquals(
            'Purchased',
            createdAsset.Status
        );

        System.assertEquals(
            'UJJAYINI-' + String.valueOf(orderRecord.Id),
            createdAsset.SerialNumber
        );
    }


    @IsTest
    static void testAlreadyFulfilledOrder() {

        Account accountRecord = new Account(
            Name = 'UJJAYINI Existing Asset Customer'
        );
        insert accountRecord;

        Product2 product = new Product2(
            Name = 'UJJAYINI Existing Watch',
            IsActive = true
        );
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry standardEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 15000,
            IsActive = true
        );
        insert standardEntry;

        Pricebook2 pricebook = new Pricebook2(
            Name = 'UJJAYINI Existing Test Pricebook',
            IsActive = true
        );
        insert pricebook;

        PricebookEntry customEntry = new PricebookEntry(
            Pricebook2Id = pricebook.Id,
            Product2Id = product.Id,
            UnitPrice = 15000,
            IsActive = true
        );
        insert customEntry;

        Order orderRecord = new Order(
            AccountId = accountRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = pricebook.Id
        );
        insert orderRecord;

        OrderItem orderItem = new OrderItem(
            OrderId = orderRecord.Id,
            PricebookEntryId = customEntry.Id,
            Quantity = 1,
            UnitPrice = 15000
        );
        insert orderItem;

        orderRecord.Status = 'Activated';
        update orderRecord;

        Asset existingAsset = new Asset(
            Name = 'UJJAYINI Existing Asset',
            AccountId = accountRecord.Id,
            Product2Id = product.Id,
            Quantity = 1,
            Price = 15000,
            PurchaseDate = Date.today(),
            Status = 'Purchased',
            SerialNumber = 'UJJAYINI-' + String.valueOf(orderRecord.Id),
            Description = 'Existing UJJAYINI Asset'
        );
        insert existingAsset;

        Test.startTest();

        AssetFulfillmentService.FulfillmentResult result =
            AssetFulfillmentService.createAssetsForOrder(
                orderRecord.Id
            );

        Test.stopTest();

        System.assertEquals(
            'ALREADY_FULFILLED',
            result.status
        );

        System.assertEquals(
            1,
            result.assetIds.size()
        );

        System.assertEquals(
            existingAsset.Id,
            result.assetIds[0]
        );
    }


    @IsTest
    static void testOrderMustBeActivated() {

        Account accountRecord = new Account(
            Name = 'UJJAYINI Draft Customer'
        );
        insert accountRecord;

        Product2 product = new Product2(
            Name = 'UJJAYINI Draft Watch',
            IsActive = true
        );
        insert product;

       Id standardPricebookId = Test.getStandardPricebookId();

PricebookEntry standardEntry = new PricebookEntry(
    Pricebook2Id = standardPricebookId,
    Product2Id = product.Id,
    UnitPrice = 5000,
    IsActive = true
);
insert standardEntry;

Pricebook2 pricebook = new Pricebook2(
    Name = 'UJJAYINI Draft Pricebook',
    IsActive = true
);
insert pricebook;

PricebookEntry pricebookEntry = new PricebookEntry(
    Pricebook2Id = pricebook.Id,
    Product2Id = product.Id,
    UnitPrice = 5000,
    IsActive = true
);
insert pricebookEntry;

        Order orderRecord = new Order(
            AccountId = accountRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = pricebook.Id
        );
        insert orderRecord;

        Test.startTest();

        try {
            AssetFulfillmentService.createAssetsForOrder(
                orderRecord.Id
            );

            System.assert(
                false,
                'Expected exception was not thrown.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Assets can only be created for an Activated Order.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}