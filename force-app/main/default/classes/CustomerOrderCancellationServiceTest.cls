@IsTest
private class CustomerOrderCancellationServiceTest {

    private class RefundMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            HttpResponse response = new HttpResponse();

            response.setStatusCode(200);

            response.setHeader('Content-Type', 'application/json');

            response.setBody(
                '{"id":"rfnd_TEST1","status":"processed",' +
                '"amount":100000,"currency":"INR",' +
                '"payment_id":"pay_TEST1"}'
            );

            return response;
        }
    }


    @TestSetup
    static void setupData() {

        Account account = new Account(Name = 'Cancellation Customer');
        insert account;

        Product2 product = new Product2(
            Name = 'Cancellation Test Watch',
            IsActive = true
        );
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert entry;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId
        );
        insert orderRecord;

        insert new OrderItem(
            OrderId = orderRecord.Id,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = 1000
        );

        orderRecord.Status = 'Activated';
        update orderRecord;

        insert new Payment__c(
            Order__c = orderRecord.Id,
            Amount__c = 1000,
            Payment_Status__c = 'Captured',
            Gateway_Order_ID__c = 'plink_TEST1',
            Gateway_Payment_ID__c = 'pay_TEST1',
            Paid_At__c = System.now()
        );

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 4,
            Reserved__c = 0,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        insert new Reservation__c(
            Inventory__c = inventory.Id,
            Order__c = orderRecord.Id,
            Reserved_Quantity__c = 1,
            Reservation_Status__c = 'Confirmed',
            Reservation_Created_At__c = System.now()
        );

        Asset asset = new Asset(
            Name = 'UJJAYINI Test Asset',
            AccountId = account.Id,
            Product2Id = product.Id,
            Quantity = 1,
            Status = 'Purchased',
            SerialNumber = 'UJJAYINI-' + String.valueOf(orderRecord.Id)
        );
        insert asset;

        insert new Warranty__c(
            Asset__c = asset.Id,
            Warranty_Status__c = 'Active',
            Warranty_Coverage_Type__c = 'Standard',
            Warranty_Duration__c = 24,
            Warranty_Start_Date__c = Date.today(),
            Warranty_End_Date__c = Date.today().addMonths(24)
        );
    }


    @IsTest
    static void cancellationRefundsRestocksAndVoids() {

        Order orderRecord = [SELECT Id, AccountId FROM Order LIMIT 1];

        CustomerOrderCancellationService.testAccountId =
            orderRecord.AccountId;

        Test.setMock(HttpCalloutMock.class, new RefundMock());

        Test.startTest();

        CustomerOrderCancellationService.CancellationResult result =
            CustomerOrderCancellationService.cancelMyOrder(orderRecord.Id);

        Test.stopTest();

        System.assertEquals(true, result.refunded);

        Order cancelled = [
            SELECT Is_Cancelled__c, Cancellation_Reason__c
            FROM Order
            WHERE Id = :orderRecord.Id
        ];

        System.assertEquals(true, cancelled.Is_Cancelled__c);
        System.assertEquals('Customer Request', cancelled.Cancellation_Reason__c);

        Payment__c payment = [
            SELECT Payment_Status__c, Gateway_Refund_ID__c
            FROM Payment__c
            WHERE Order__c = :orderRecord.Id
        ];

        System.assertEquals('Refunded', payment.Payment_Status__c);
        System.assertEquals('rfnd_TEST1', payment.Gateway_Refund_ID__c);

        Inventory__c inventory = [SELECT On_Hand__c FROM Inventory__c LIMIT 1];

        System.assertEquals(5, inventory.On_Hand__c);

        Reservation__c reservation = [
            SELECT Reservation_Status__c
            FROM Reservation__c
            LIMIT 1
        ];

        System.assertEquals('Released', reservation.Reservation_Status__c);

        Warranty__c warranty = [SELECT Warranty_Status__c FROM Warranty__c LIMIT 1];

        System.assertEquals('Voided', warranty.Warranty_Status__c);
    }


    @IsTest
    static void anotherCustomerCannotCancel() {

        Order orderRecord = [SELECT Id FROM Order LIMIT 1];

        Account stranger = new Account(Name = 'Another Customer');
        insert stranger;

        CustomerOrderCancellationService.testAccountId = stranger.Id;

        Test.setMock(HttpCalloutMock.class, new RefundMock());

        Boolean rejected = false;

        Test.startTest();

        try {

            CustomerOrderCancellationService.cancelMyOrder(orderRecord.Id);

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('Order not found'));
        }

        Test.stopTest();

        System.assertEquals(true, rejected);

        System.assertEquals(
            false,
            [SELECT Is_Cancelled__c FROM Order WHERE Id = :orderRecord.Id]
                .Is_Cancelled__c
        );
    }


    @IsTest
    static void orderCannotBeCancelledTwice() {

        Order orderRecord = [SELECT Id, AccountId FROM Order LIMIT 1];

        orderRecord.Is_Cancelled__c = true;
        update orderRecord;

        CustomerOrderCancellationService.testAccountId =
            orderRecord.AccountId;

        Boolean rejected = false;

        Test.startTest();

        try {

            CustomerOrderCancellationService.cancelMyOrder(orderRecord.Id);

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('already been cancelled'));
        }

        Test.stopTest();

        System.assertEquals(true, rejected);
    }
    @IsTest
    static void shippedOrderCannotBeCancelled() {

        Order orderRecord = [SELECT Id, AccountId FROM Order LIMIT 1];

        orderRecord.Fulfillment_Status__c = 'Shipped';
        update orderRecord;

        CustomerOrderCancellationService.testAccountId =
            orderRecord.AccountId;

        Boolean rejected = false;

        Test.startTest();

        try {

            CustomerOrderCancellationService.cancelMyOrder(orderRecord.Id);

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('already been shipped'));
        }

        Test.stopTest();

        System.assertEquals(true, rejected);
    }
}