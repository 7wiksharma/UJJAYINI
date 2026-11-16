@IsTest
private class OrderCancellationServiceTest {

    @IsTest
    static void testCancelActivatedOrder() {

        Account account = new Account(
            Name = 'UJJAYINI Cancellation Test Account'
        );
        insert account;

        Product2 product = new Product2(
            Name = 'UJJAYINI Cancellation Test Watch',
            IsActive = true
        );
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert pricebookEntry;

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 10,
            Reserved__c = 2,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        Order testOrder = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert testOrder;

        OrderItem orderItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 1000
        );
        insert orderItem;

        testOrder.Status = 'Activated';
        update testOrder;

        Reservation__c reservation = new Reservation__c(
            Inventory__c = inventory.Id,
            Order__c = testOrder.Id,
            Reserved_Quantity__c = 2,
            Reservation_Status__c = 'Pending',
            Reservation_Created_At__c = System.now(),
            Reservation_Expires_At__c = System.now().addMinutes(15)
        );
        insert reservation;

        Test.startTest();

        OrderCancellationService.cancelOrder(
            testOrder.Id,
            'Customer Request'
        );

        Test.stopTest();

        Order cancelledOrder = [
            SELECT Id,
                   Status,
                   Is_Cancelled__c,
                   Cancellation_Reason__c,
                   Cancelled_At__c
            FROM Order
            WHERE Id = :testOrder.Id
        ];

        Reservation__c cancelledReservation = [
            SELECT Id,
                   Reservation_Status__c
            FROM Reservation__c
            WHERE Id = :reservation.Id
        ];

        Inventory__c updatedInventory = [
            SELECT Id,
                   Reserved__c
            FROM Inventory__c
            WHERE Id = :inventory.Id
        ];

        System.assertEquals(
            'Activated',
            cancelledOrder.Status,
            'Order Status should remain Activated.'
        );

        System.assertEquals(
            true,
            cancelledOrder.Is_Cancelled__c,
            'Order should be marked cancelled.'
        );

        System.assertEquals(
            'Customer Request',
            cancelledOrder.Cancellation_Reason__c,
            'Cancellation reason should be stored.'
        );

        System.assertNotEquals(
            null,
            cancelledOrder.Cancelled_At__c,
            'Cancelled At should be populated.'
        );

        System.assertEquals(
            'Cancelled',
            cancelledReservation.Reservation_Status__c,
            'Pending reservation should be cancelled.'
        );

        System.assertEquals(
            0,
            updatedInventory.Reserved__c,
            'Reserved inventory should be released.'
        );
    }


    @IsTest
    static void testCannotCancelAlreadyCancelledOrder() {

        Account account = new Account(
            Name = 'UJJAYINI Already Cancelled Test Account'
        );
        insert account;

        Product2 product = new Product2(
            Name = 'UJJAYINI Already Cancelled Test Watch',
            IsActive = true
        );
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert pricebookEntry;

        Order testOrder = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert testOrder;

        OrderItem orderItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 1000
        );
        insert orderItem;

        testOrder.Status = 'Activated';
        update testOrder;

        testOrder.Is_Cancelled__c = true;
        testOrder.Cancellation_Reason__c = 'Customer Request';
        testOrder.Cancelled_At__c = System.now();
        update testOrder;

        Test.startTest();

        try {

            OrderCancellationService.cancelOrder(
                testOrder.Id,
                'Other'
            );

            System.assert(
                false,
                'Expected exception for already cancelled order.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Order is already cancelled.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testCannotCancelDraftOrder() {

        Account account = new Account(
            Name = 'UJJAYINI Draft Cancellation Test Account'
        );
        insert account;

        Order testOrder = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert testOrder;

        Test.startTest();

        try {

            OrderCancellationService.cancelOrder(
                testOrder.Id,
                'Customer Request'
            );

            System.assert(
                false,
                'Expected exception for Draft order.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Only Activated orders can be cancelled.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testCancellationReasonIsRequired() {

        Account account = new Account(
            Name = 'UJJAYINI Reason Test Account'
        );
        insert account;

        Product2 product = new Product2(
            Name = 'UJJAYINI Reason Test Watch',
            IsActive = true
        );
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert pricebookEntry;

        Order testOrder = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert testOrder;

        OrderItem orderItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 1000
        );
        insert orderItem;

        testOrder.Status = 'Activated';
        update testOrder;

        Test.startTest();

        try {

            OrderCancellationService.cancelOrder(
                testOrder.Id,
                null
            );

            System.assert(
                false,
                'Expected exception when cancellation reason is missing.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Cancellation reason is required.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}