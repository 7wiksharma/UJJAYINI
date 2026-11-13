@IsTest
private class RazorpayWebhookEndpointTest {

    private static String webhookSecret =
        'test-webhook-secret-123';

    private static String paymentLinkId =
        'plink_test_123';

    private static String razorpayPaymentId =
        'pay_test_123';


    /*
     * ============================================================
     * WEBHOOK PAYLOAD
     * ============================================================
     */
    private static String buildPayload(
        String eventType
    ) {

        return '{"entity":"event",' +
               '"account_id":"acc_test_123",' +
               '"event":"' + eventType + '",' +
               '"payload":{' +

                   '"payment_link":{' +
                       '"entity":{' +
                           '"id":"' + paymentLinkId + '"' +
                       '}' +
                   '},' +

                   '"payment":{' +
                       '"entity":{' +
                           '"id":"' + razorpayPaymentId + '",' +
                           '"amount":5000000,' +
                           '"currency":"INR",' +
                           '"status":"captured"' +
                       '}' +
                   '}' +

               '}}';
    }


    /*
     * ============================================================
     * SIGNATURE
     * ============================================================
     */
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


    /*
     * ============================================================
     * WEBHOOK SETTINGS
     * ============================================================
     */
    private static void createWebhookSettings() {

        UJJAYINI_Integration_Settings__c settings =
            new UJJAYINI_Integration_Settings__c();

        settings.Name =
            'UJJAYINI Integration Settings';

        settings.Razorpay_Webhook_Secret__c =
            webhookSecret;

        insert settings;
    }


    /*
     * ============================================================
     * TEST DATA
     * ============================================================
     */
    private static Id createTestOrder() {

        Account account = new Account(
            Name = 'UJJAYINI Test Customer'
        );

        insert account;


        Product2 product = new Product2(
            Name = 'UJJAYINI Test Watch',
            IsActive = true
        );

        insert product;


        Id standardPricebookId =
            Test.getStandardPricebookId();


        PricebookEntry pricebookEntry =
            new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = product.Id,
                UnitPrice = 50000,
                IsActive = true
            );

        insert pricebookEntry;


        Order orderRecord =
            new Order(
                AccountId = account.Id,
                EffectiveDate = Date.today(),
                Status = 'Draft',
                Pricebook2Id = standardPricebookId
            );

        insert orderRecord;


        OrderItem orderItem =
            new OrderItem(
                OrderId = orderRecord.Id,
                PricebookEntryId = pricebookEntry.Id,
                Quantity = 1,
                UnitPrice = 50000
            );

        insert orderItem;


        /*
         * Payment__c is the business/idempotency anchor
         * for the new Payment Link webhook architecture.
         */
        Payment__c payment =
            new Payment__c(
                Order__c = orderRecord.Id,
                Amount__c = 50000,
                Payment_Status__c = 'Pending',
                Gateway_Order_ID__c = paymentLinkId
            );

        insert payment;


        return orderRecord.Id;
    }


    /*
     * ============================================================
     * VALID PAYMENT LINK WEBHOOK
     * ============================================================
     */
    @IsTest
    static void acceptsValidWebhook() {

        createWebhookSettings();

        Id orderId =
            createTestOrder();

        String payload =
            buildPayload('payment_link.paid');

        String signature =
            generateSignature(payload);


        RestRequest request =
            new RestRequest();

        request.requestURI =
            '/services/apexrest/razorpay/webhook/';

        request.httpMethod =
            'POST';

        request.requestBody =
            Blob.valueOf(payload);


        request.addHeader(
            'X-Razorpay-Signature',
            signature
        );

        request.addHeader(
            'X-Razorpay-Event-Id',
            'evt_endpoint_001'
        );


        RestContext.request =
            request;

        RestContext.response =
            new RestResponse();


        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();


        /*
         * Endpoint should return HTTP 200.
         */
        System.assertEquals(
            200,
            RestContext.response.statusCode
        );


        String responseBody =
            RestContext.response
                .responseBody
                .toString();


        System.assert(
            responseBody.contains(
                '"success":true'
            ),
            'Expected successful webhook response.'
        );


        /*
         * Payment must be captured.
         */
        Payment__c payment =
            [
                SELECT Id,
                       Order__c,
                       Payment_Status__c,
                       Gateway_Order_ID__c,
                       Gateway_Payment_ID__c,
                       Paid_At__c
                FROM Payment__c
                WHERE Gateway_Order_ID__c =
                    :paymentLinkId
                LIMIT 1
            ];


        System.assertEquals(
            'Captured',
            payment.Payment_Status__c
        );


        System.assertEquals(
            razorpayPaymentId,
            payment.Gateway_Payment_ID__c
        );


        System.assertNotEquals(
            null,
            payment.Paid_At__c
        );


        /*
         * Order must be activated.
         */
        Order activatedOrder =
            [
                SELECT Id,
                       Status
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];


        System.assertEquals(
            'Activated',
            activatedOrder.Status
        );


        /*
         * Webhook audit record must exist.
         */
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Webhook_Event__c
                WHERE Event_ID__c =
                    'evt_endpoint_001'
            ]
        );


        /*
         * Asset must be created.
         */
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Asset
                WHERE SerialNumber =
                    :('UJJAYINI-' + String.valueOf(orderId))
            ]
        );
    }


    /*
     * ============================================================
     * INVALID SIGNATURE
     * ============================================================
     */
    @IsTest
    static void rejectsInvalidSignature() {

        createWebhookSettings();

        String payload =
            buildPayload('payment_link.paid');


        RestRequest request =
            new RestRequest();

        request.requestURI =
            '/services/apexrest/razorpay/webhook/';

        request.httpMethod =
            'POST';

        request.requestBody =
            Blob.valueOf(payload);


        request.addHeader(
            'X-Razorpay-Signature',
            'invalid-signature'
        );

        request.addHeader(
            'X-Razorpay-Event-Id',
            'evt_endpoint_invalid'
        );


        RestContext.request =
            request;

        RestContext.response =
            new RestResponse();


        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();


        System.assertEquals(
            400,
            RestContext.response.statusCode
        );


        String responseBody =
            RestContext.response
                .responseBody
                .toString();


        System.assert(
            responseBody.contains(
                '"success":false'
            ),
            'Expected failed webhook response.'
        );


        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Webhook_Event__c
                WHERE Event_ID__c =
                    'evt_endpoint_invalid'
            ]
        );
    }


    /*
     * ============================================================
     * MISSING SIGNATURE
     * ============================================================
     */
    @IsTest
    static void rejectsMissingSignature() {

        createWebhookSettings();

        String payload =
            buildPayload('payment_link.paid');


        RestRequest request =
            new RestRequest();

        request.requestURI =
            '/services/apexrest/razorpay/webhook/';

        request.httpMethod =
            'POST';

        request.requestBody =
            Blob.valueOf(payload);


        request.addHeader(
            'X-Razorpay-Event-Id',
            'evt_endpoint_missing_signature'
        );


        RestContext.request =
            request;

        RestContext.response =
            new RestResponse();


        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();


        System.assertEquals(
            400,
            RestContext.response.statusCode
        );


        System.assert(
            RestContext.response
                .responseBody
                .toString()
                .contains(
                    '"success":false'
                ),
            'Expected failed webhook response.'
        );
    }


    /*
     * ============================================================
     * MISSING EVENT ID
     * ============================================================
     */
    @IsTest
    static void rejectsMissingEventId() {

        createWebhookSettings();

        String payload =
            buildPayload('payment_link.paid');

        String signature =
            generateSignature(payload);


        RestRequest request =
            new RestRequest();

        request.requestURI =
            '/services/apexrest/razorpay/webhook/';

        request.httpMethod =
            'POST';

        request.requestBody =
            Blob.valueOf(payload);


        request.addHeader(
            'X-Razorpay-Signature',
            signature
        );


        RestContext.request =
            request;

        RestContext.response =
            new RestResponse();


        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();


        System.assertEquals(
            400,
            RestContext.response.statusCode
        );


        System.assert(
            RestContext.response
                .responseBody
                .toString()
                .contains(
                    '"success":false'
                ),
            'Expected failed webhook response.'
        );
    }
}