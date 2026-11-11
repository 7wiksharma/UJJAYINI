@IsTest
private class RazorpayWebhookServiceTest {

    private static String webhookSecret =
        'test-webhook-secret-123';


    private static String buildPayload() {

        return '{"entity":"event",' +
               '"account_id":"acc_test_123",' +
               '"event":"payment.captured",' +
               '"payload":{' +
                   '"payment":{' +
                       '"entity":{' +
                           '"id":"pay_test_123",' +
                           '"amount":5000000,' +
                           '"currency":"INR",' +
                           '"status":"captured"' +
                       '}' +
                   '},' +
                   '"order":{' +
                       '"entity":{' +
                           '"id":"order_test_123",' +
                           '"amount":5000000,' +
                           '"currency":"INR",' +
                           '"status":"paid"' +
                       '}' +
                   '}' +
               '}}';
    }


    private static String generateSignature(
        String payload
    ) {

        Blob payloadBlob =
            Blob.valueOf(payload);

        Blob secretBlob =
            Blob.valueOf(webhookSecret);

        Blob signature =
            Crypto.generateMac(
                'HmacSHA256',
                payloadBlob,
                secretBlob
            );

        return EncodingUtil.convertToHex(
            signature
        );
    }


    private static void createWebhookSettings() {

        UJJAYINI_Integration_Settings__c settings =
            new UJJAYINI_Integration_Settings__c();

        settings.Name =
            'UJJAYINI Integration Settings';

        settings.Razorpay_Webhook_Secret__c =
            webhookSecret;

        insert settings;
    }


    private static Payment__c createPaymentData() {

        Account account = new Account(
            Name = 'Webhook Test Account'
        );

        insert account;


        Product2 product = new Product2(
            Name = 'Webhook Test Watch',
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
                Name = 'Webhook Test Pricebook',
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


        Payment__c payment =
            new Payment__c(
                Order__c = orderRecord.Id,
                Amount__c = 50000,
                Payment_Status__c = 'Pending',
                Gateway_Order_ID__c = 'order_test_123'
            );

        insert payment;


        return payment;
    }


    @IsTest
    static void processesValidWebhook() {

        createWebhookSettings();

        Payment__c payment =
            createPaymentData();

        String payload =
            buildPayload();

        String signature =
            generateSignature(payload);


        RazorpayWebhookService.WebhookRequest request =
            new RazorpayWebhookService.WebhookRequest();

        request.eventId =
            'evt_test_001';

        request.rawPayload =
            payload;

        request.signature =
            signature;


        Test.startTest();

        RazorpayWebhookService.WebhookResult result =
            RazorpayWebhookService.processWebhook(
                request
            );

        Test.stopTest();


        /*
         * Verify webhook result.
         */
        System.assertNotEquals(
            null,
            result.webhookEventId
        );

        System.assertEquals(
            'Processed',
            result.processingStatus
        );

        System.assertEquals(
            true,
            result.signatureVerified
        );

        System.assertEquals(
            false,
            result.duplicate
        );


        /*
         * Verify Payment.
         */
        Payment__c updatedPayment = [
            SELECT Id,
                   Order__c,
                   Payment_Status__c,
                   Gateway_Order_ID__c,
                   Gateway_Payment_ID__c,
                   Paid_At__c
            FROM Payment__c
            WHERE Id = :payment.Id
        ];


        System.assertEquals(
            'Captured',
            updatedPayment.Payment_Status__c
        );

        System.assertEquals(
            'order_test_123',
            updatedPayment.Gateway_Order_ID__c
        );

        System.assertEquals(
            'pay_test_123',
            updatedPayment.Gateway_Payment_ID__c
        );

        System.assertNotEquals(
            null,
            updatedPayment.Paid_At__c
        );


        /*
         * Verify Order.
         */
        Order updatedOrder = [
            SELECT Id,
                   AccountId,
                   Status
            FROM Order
            WHERE Id = :payment.Order__c
        ];


        System.assertEquals(
            'Activated',
            updatedOrder.Status
        );


        /*
         * Verify Asset fulfillment.
         *
         * AssetFulfillmentService uses:
         *
         * SerialNumber =
         * 'UJJAYINI-' + Order Id
         *
         * Description is intentionally NOT used
         * in the WHERE clause because Asset.Description
         * cannot be filtered in SOQL.
         */
        String expectedSerialNumber =
            'UJJAYINI-' +
            String.valueOf(payment.Order__c);


        List<Asset> createdAssets = [
            SELECT Id,
                   Name,
                   AccountId,
                   Product2Id,
                   Quantity,
                   Price,
                   PurchaseDate,
                   Status,
                   SerialNumber,
                   Description
            FROM Asset
            WHERE SerialNumber =
                :expectedSerialNumber
        ];


        System.assertEquals(
            1,
            createdAssets.size()
        );


        Asset createdAsset =
            createdAssets[0];


        System.assertEquals(
            updatedOrder.AccountId,
            createdAsset.AccountId
        );


        System.assertNotEquals(
            null,
            createdAsset.Product2Id
        );


        System.assertEquals(
            1,
            createdAsset.Quantity
        );


        System.assertEquals(
            50000,
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
            expectedSerialNumber,
            createdAsset.SerialNumber
        );


        System.assertEquals(
            'UJJAYINI Order ' +
            String.valueOf(payment.Order__c),
            createdAsset.Description
        );


        /*
         * Verify Asset Name.
         */
        OrderItem createdOrderItem = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId = :payment.Order__c
            LIMIT 1
        ];


        System.assertEquals(
            'UJJAYINI Asset - ' +
            String.valueOf(createdOrderItem.Id),
            createdAsset.Name
        );


        /*
         * Verify Webhook Event.
         */
        Webhook_Event__c eventRecord = [
            SELECT Event_ID__c,
                   Event_Type__c,
                   Processing_Status__c,
                   Signature_Verified__c,
                   Raw_Payload__c
            FROM Webhook_Event__c
            WHERE Id = :result.webhookEventId
        ];


        System.assertEquals(
            'evt_test_001',
            eventRecord.Event_ID__c
        );

        System.assertEquals(
            'Payment Captured',
            eventRecord.Event_Type__c
        );

        System.assertEquals(
            'Processed',
            eventRecord.Processing_Status__c
        );

        System.assertEquals(
            true,
            eventRecord.Signature_Verified__c
        );

        System.assertEquals(
            payload,
            eventRecord.Raw_Payload__c
        );
    }


    @IsTest
    static void rejectsInvalidSignature() {

        createWebhookSettings();

        String payload =
            buildPayload();

        RazorpayWebhookService.WebhookRequest request =
            new RazorpayWebhookService.WebhookRequest();

        request.eventId =
            'evt_test_invalid';

        request.rawPayload =
            payload;

        request.signature =
            'invalid-signature';


        Test.startTest();

        try {

            RazorpayWebhookService.processWebhook(
                request
            );

            System.assert(
                false,
                'Expected invalid signature to be rejected.'
            );

        } catch (
            RazorpayWebhookService.WebhookSecurityException e
        ) {

            System.assertEquals(
                'Invalid Razorpay webhook signature.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectsMissingSignature() {

        createWebhookSettings();

        RazorpayWebhookService.WebhookRequest request =
            new RazorpayWebhookService.WebhookRequest();

        request.eventId =
            'evt_test_missing_signature';

        request.rawPayload =
            buildPayload();

        request.signature =
            null;


        Test.startTest();

        try {

            RazorpayWebhookService.processWebhook(
                request
            );

            System.assert(
                false,
                'Expected missing signature to be rejected.'
            );

        } catch (
            RazorpayWebhookService.WebhookSecurityException e
        ) {

            System.assertEquals(
                'Webhook signature is required.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectsWhenSecretIsNotConfigured() {

        String payload =
            buildPayload();

        String signature =
            generateSignature(payload);


        RazorpayWebhookService.WebhookRequest request =
            new RazorpayWebhookService.WebhookRequest();

        request.eventId =
            'evt_test_no_secret';

        request.rawPayload =
            payload;

        request.signature =
            signature;


        Test.startTest();

        try {

            RazorpayWebhookService.processWebhook(
                request
            );

            System.assert(
                false,
                'Expected missing webhook secret to be rejected.'
            );

        } catch (
            RazorpayWebhookService.WebhookSecurityException e
        ) {

            System.assertEquals(
                'Razorpay webhook secret is not configured.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void ignoresDuplicateWebhookEvent() {

        createWebhookSettings();

        Payment__c payment =
            createPaymentData();

        String payload =
            buildPayload();

        String signature =
            generateSignature(payload);


        RazorpayWebhookService.WebhookRequest request =
            new RazorpayWebhookService.WebhookRequest();

        request.eventId =
            'evt_test_duplicate';

        request.rawPayload =
            payload;

        request.signature =
            signature;


        Test.startTest();

        RazorpayWebhookService.WebhookResult firstResult =
            RazorpayWebhookService.processWebhook(
                request
            );

        RazorpayWebhookService.WebhookResult secondResult =
            RazorpayWebhookService.processWebhook(
                request
            );

        Test.stopTest();


        /*
         * Verify first webhook was processed.
         */
        System.assertEquals(
            false,
            firstResult.duplicate
        );


        /*
         * Verify second webhook was ignored
         * as duplicate.
         */
        System.assertEquals(
            true,
            secondResult.duplicate
        );


        System.assertEquals(
            firstResult.webhookEventId,
            secondResult.webhookEventId
        );


        /*
         * Only one Webhook Event should exist.
         */
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Webhook_Event__c
                WHERE Event_ID__c =
                    'evt_test_duplicate'
            ]
        );


        /*
         * Only one Asset should exist.
         *
         * This also proves that the duplicate
         * webhook did not create another Asset.
         */
        String expectedSerialNumber =
            'UJJAYINI-' +
            String.valueOf(payment.Order__c);


        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Asset
                WHERE SerialNumber =
                    :expectedSerialNumber
            ]
        );
    }
}