@IsTest
private class UJJAYINICheckoutControllerTest {

    private static Id createTestOrder() {

        Account account = new Account(
            Name = 'UJJAYINI Checkout Test Account'
        );
        insert account;


        Product2 product = new Product2(
            Name = 'UJJAYINI Checkout Test Watch',
            IsActive = true
        );
        insert product;


        Id standardPricebookId =
            Test.getStandardPricebookId();


        PricebookEntry standardEntry =
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = product.Id,
                UnitPrice = 50000,
                IsActive = true
            );
        insert standardEntry;


        Pricebook2 customPricebook =
            new Pricebook2(
                Name = 'UJJAYINI Checkout Test Pricebook',
                IsActive = true
            );
        insert customPricebook;


        PricebookEntry customEntry =
            new PricebookEntry(
                Pricebook2Id = customPricebook.Id,
                Product2Id = product.Id,
                UnitPrice = 50000,
                IsActive = true
            );
        insert customEntry;


        Order orderRecord =
            new Order(
                AccountId = account.Id,
                EffectiveDate = Date.today(),
                Status = 'Draft',
                Pricebook2Id = customPricebook.Id
            );
        insert orderRecord;


        OrderItem orderItem =
            new OrderItem(
                OrderId = orderRecord.Id,
                PricebookEntryId = customEntry.Id,
                Quantity = 1,
                UnitPrice = 50000
            );
        insert orderItem;


        return orderRecord.Id;
    }


    @IsTest
    static void rejectsNullOrderId() {

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            UJJAYINICheckoutController.checkout(
                null,
                'UPI'
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();


        System.assertEquals(
            true,
            exceptionThrown,
            'Expected null Order Id to be rejected.'
        );
    }


    @IsTest
    static void rejectsOrderWithoutItems() {

        Account account = new Account(
            Name = 'UJJAYINI Empty Checkout Account'
        );
        insert account;


        Pricebook2 pricebook =
            new Pricebook2(
                Name = 'UJJAYINI Empty Checkout Pricebook',
                IsActive = true
            );
        insert pricebook;


        Order orderRecord =
            new Order(
                AccountId = account.Id,
                EffectiveDate = Date.today(),
                Status = 'Draft',
                Pricebook2Id = pricebook.Id
            );
        insert orderRecord;


        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            UJJAYINICheckoutController.checkout(
                orderRecord.Id,
                'UPI'
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();


        System.assertEquals(
            true,
            exceptionThrown,
            'Expected order without items to be rejected.'
        );
    }


    @IsTest
    static void checkoutWithValidOrder() {

        Id orderId =
            createTestOrder();


        /*
         * Mock Razorpay callout.
         */
        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayOrderMock()
        );


        /*
         * Get the Product used by the Order Item.
         */
        OrderItem orderItem = [
            SELECT Product2Id
            FROM OrderItem
            WHERE OrderId = :orderId
            LIMIT 1
        ];


        /*
         * Create inventory.
         */
        Inventory__c inventory =
            new Inventory__c(
                Product__c = orderItem.Product2Id,
                On_Hand__c = 10,
                Reserved__c = 0,
                Inventory_Status__c = 'Active'
            );

        insert inventory;


        Test.startTest();

        OrderCheckoutService.CheckoutResult result =
            UJJAYINICheckoutController.checkout(
                orderId,
                'UPI'
            );

        Test.stopTest();


        /*
         * Verify controller result.
         */
        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            orderId,
            result.orderId
        );

        System.assertNotEquals(
            null,
            result.paymentId
        );

        System.assertNotEquals(
            null,
            result.reservationId
        );

        System.assertEquals(
            'READY_FOR_PAYMENT',
            result.status
        );

        System.assertEquals(
            'order_test_controller',
            result.gatewayOrderId
        );


        /*
         * Verify Payment.
         */
        Payment__c payment = [
            SELECT Id,
                   Order__c,
                   Amount__c,
                   Payment_Status__c,
                   Payment_Method__c,
                   Gateway_Order_ID__c
            FROM Payment__c
            WHERE Id = :result.paymentId
        ];


        System.assertEquals(
            orderId,
            payment.Order__c
        );

        System.assertEquals(
            50000,
            payment.Amount__c
        );

        System.assertEquals(
            'Pending',
            payment.Payment_Status__c
        );

        System.assertEquals(
            'UPI',
            payment.Payment_Method__c
        );

        System.assertEquals(
            'order_test_controller',
            payment.Gateway_Order_ID__c
        );


        /*
         * Verify Reservation.
         */
        Reservation__c reservation = [
            SELECT Id,
                   Order__c,
                   Inventory__c,
                   Reserved_Quantity__c,
                   Reservation_Status__c
            FROM Reservation__c
            WHERE Id = :result.reservationId
        ];


        System.assertEquals(
            orderId,
            reservation.Order__c
        );

        System.assertEquals(
            1,
            reservation.Reserved_Quantity__c
        );

        System.assertEquals(
            'Pending',
            reservation.Reservation_Status__c
        );


        /*
         * Verify Inventory.
         */
        Inventory__c updatedInventory = [
            SELECT Id,
                   On_Hand__c,
                   Reserved__c,
                   Available__c
            FROM Inventory__c
            WHERE Id = :inventory.Id
        ];


        System.assertEquals(
            10,
            updatedInventory.On_Hand__c
        );

        System.assertEquals(
            1,
            updatedInventory.Reserved__c
        );

        System.assertEquals(
            9,
            updatedInventory.Available__c
        );
    }


    private class RazorpayOrderMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest request
        ) {

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{"id":"order_test_controller",' +
                '"entity":"order",' +
                '"amount":5000000,' +
                '"amount_paid":0,' +
                '"amount_due":5000000,' +
                '"currency":"INR",' +
                '"receipt":"UJ-test",' +
                '"status":"created"}'
            );

            return response;
        }
    }
}