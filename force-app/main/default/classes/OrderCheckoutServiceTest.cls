@IsTest
private class OrderCheckoutServiceTest {

    /*
     * Mock Razorpay order creation callout.
     */
    private class RazorpayOrderMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            HttpResponse response = new HttpResponse();

            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');

            response.setBody(
                '{' +
                    '"id":"order_test_UJJAYINI_001",' +
                    '"entity":"order",' +
                    '"amount":500000,' +
                    '"amount_paid":0,' +
                    '"amount_due":500000,' +
                    '"currency":"INR",' +
                    '"receipt":"UJ-TEST",' +
                    '"status":"created"' +
                '}'
            );

            return response;
        }
    }


    @IsTest
    static void testNullRequest() {

        Test.startTest();

        try {
            OrderCheckoutService.checkout(null);

            System.assert(
                false,
                'Expected exception was not thrown.'
            );

        } catch (Exception e) {

            System.assertEquals(
                'Order ID is required.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testDraftOrderWithoutItems() {

        Account accountRecord = new Account(
            Name = 'UJJAYINI Test Account'
        );

        insert accountRecord;

        Order orderRecord = new Order(
            AccountId = accountRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );

        insert orderRecord;

        OrderCheckoutService.CheckoutRequest request =
            new OrderCheckoutService.CheckoutRequest();

        request.orderId = orderRecord.Id;

        Test.startTest();

        try {

            OrderCheckoutService.checkout(request);

            System.assert(
                false,
                'Expected exception was not thrown.'
            );

        } catch (Exception e) {

            System.assertEquals(
                'Order must contain at least one product.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testCheckoutSuccess() {

        /*
         * Create Account.
         */
        Account accountRecord = new Account(
            Name = 'UJJAYINI Checkout Test Account'
        );

        insert accountRecord;


        /*
         * Create Product.
         */
        Product2 productRecord = new Product2(
            Name = 'UJJAYINI Test Watch',
            IsActive = true
        );

        insert productRecord;


        /*
 * Get the Standard Pricebook.
 */
Id standardPricebookId = Test.getStandardPricebookId();


/*
 * Create Standard Pricebook Entry.
 */
PricebookEntry standardPricebookEntry =
    new PricebookEntry(
        Pricebook2Id = standardPricebookId,
        Product2Id = productRecord.Id,
        UnitPrice = 5000,
        IsActive = true
    );

insert standardPricebookEntry;


/*
 * Create Custom Pricebook.
 */
Pricebook2 pricebookRecord = new Pricebook2(
    Name = 'UJJAYINI Test Pricebook',
    IsActive = true
);

insert pricebookRecord;


/*
 * Create Custom Pricebook Entry.
 */
PricebookEntry pricebookEntry =
    new PricebookEntry(
        Pricebook2Id = pricebookRecord.Id,
        Product2Id = productRecord.Id,
        UnitPrice = 5000,
        IsActive = true
    );

insert pricebookEntry;


        /*
         * Create Order.
         */
        Order orderRecord = new Order(
            AccountId = accountRecord.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = pricebookRecord.Id
        );

        insert orderRecord;


        /*
         * Create Order Item.
         */
        OrderItem orderItem = new OrderItem(
            OrderId = orderRecord.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 5000
        );

        insert orderItem;


        /*
         * Create Inventory.
         */
        Inventory__c inventoryRecord =
            new Inventory__c(
                Product__c = productRecord.Id,
                On_Hand__c = 10,
                Reserved__c = 0,
                Inventory_Status__c = 'Active'
            );

        insert inventoryRecord;


        /*
         * Register Razorpay HTTP mock.
         */
        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayOrderMock()
        );


        /*
         * Prepare checkout request.
         */
        OrderCheckoutService.CheckoutRequest request =
            new OrderCheckoutService.CheckoutRequest();

        request.orderId = orderRecord.Id;
        request.paymentMethod = 'UPI';


        /*
         * Execute checkout.
         */
        Test.startTest();

        OrderCheckoutService.CheckoutResult result =
            OrderCheckoutService.checkout(request);

        Test.stopTest();


        /*
         * Verify checkout result.
         */
        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            orderRecord.Id,
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
            'order_test_UJJAYINI_001',
            result.gatewayOrderId
        );

        System.assertEquals(
            'READY_FOR_PAYMENT',
            result.status
        );


        /*
         * Verify Inventory.
         */
        Inventory__c updatedInventory =
            [
                SELECT Id,
                       On_Hand__c,
                       Reserved__c,
                       Available__c
                FROM Inventory__c
                WHERE Id = :inventoryRecord.Id
            ];

        System.assertEquals(
            10,
            Integer.valueOf(updatedInventory.On_Hand__c)
        );

        System.assertEquals(
            1,
            Integer.valueOf(updatedInventory.Reserved__c)
        );

        System.assertEquals(
            9,
            Integer.valueOf(updatedInventory.Available__c)
        );


        /*
         * Verify Reservation.
         */
        Reservation__c reservation =
            [
                SELECT Id,
                       Order__c,
                       Inventory__c,
                       Reserved_Quantity__c,
                       Reservation_Status__c
                FROM Reservation__c
                WHERE Id = :result.reservationId
            ];

        System.assertEquals(
            orderRecord.Id,
            reservation.Order__c
        );

        System.assertEquals(
            inventoryRecord.Id,
            reservation.Inventory__c
        );

        System.assertEquals(
            1,
            Integer.valueOf(
                reservation.Reserved_Quantity__c
            )
        );

        System.assertEquals(
            'Pending',
            reservation.Reservation_Status__c
        );


        /*
         * Verify Payment.
         */
        Payment__c payment =
            [
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
            orderRecord.Id,
            payment.Order__c
        );

        System.assertEquals(
            5000,
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
            'order_test_UJJAYINI_001',
            payment.Gateway_Order_ID__c
        );
    }
}