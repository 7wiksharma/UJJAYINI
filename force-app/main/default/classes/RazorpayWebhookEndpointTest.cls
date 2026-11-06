@IsTest
private class RazorpayWebhookEndpointTest {

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
                   '}' +
               '}}';
    }

    private static String generateSignature(
        String payload
    ) {
        Blob payloadBlob = Blob.valueOf(payload);
        Blob secretBlob = Blob.valueOf(webhookSecret);

        Blob signature = Crypto.generateMac(
            'HmacSHA256',
            payloadBlob,
            secretBlob
        );

        return EncodingUtil.convertToHex(signature);
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

    @IsTest
    static void acceptsValidWebhook() {

        createWebhookSettings();

        String payload = buildPayload();
        String signature = generateSignature(payload);

        RestRequest request = new RestRequest();
        request.requestURI =
            '/services/apexrest/razorpay/webhook/';
        request.httpMethod = 'POST';

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

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();

        System.assertEquals(
            200,
            RestContext.response.statusCode
        );

        String responseBody =
            RestContext.response.responseBody.toString();

        System.assert(
            responseBody.contains('"success":true'),
            'Expected successful webhook response.'
        );

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Webhook_Event__c
                WHERE Event_ID__c = 'evt_endpoint_001'
            ]
        );
    }

    @IsTest
    static void rejectsInvalidSignature() {

        createWebhookSettings();

        String payload = buildPayload();

        RestRequest request = new RestRequest();
        request.requestURI =
            '/services/apexrest/razorpay/webhook/';
        request.httpMethod = 'POST';

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

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();

        System.assertEquals(
            400,
            RestContext.response.statusCode
        );

        String responseBody =
            RestContext.response.responseBody.toString();

        System.assert(
            responseBody.contains('"success":false'),
            'Expected failed webhook response.'
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Webhook_Event__c
                WHERE Event_ID__c = 'evt_endpoint_invalid'
            ]
        );
    }

    @IsTest
    static void rejectsMissingSignature() {

        createWebhookSettings();

        String payload = buildPayload();

        RestRequest request = new RestRequest();
        request.requestURI =
            '/services/apexrest/razorpay/webhook/';
        request.httpMethod = 'POST';

        request.requestBody =
            Blob.valueOf(payload);

        request.addHeader(
            'X-Razorpay-Event-Id',
            'evt_endpoint_missing_signature'
        );

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();

        System.assertEquals(
            400,
            RestContext.response.statusCode
        );

        System.assert(
            RestContext.response.responseBody
                .toString()
                .contains('"success":false'),
            'Expected failed webhook response.'
        );
    }

    @IsTest
    static void rejectsMissingEventId() {

        createWebhookSettings();

        String payload = buildPayload();
        String signature = generateSignature(payload);

        RestRequest request = new RestRequest();
        request.requestURI =
            '/services/apexrest/razorpay/webhook/';
        request.httpMethod = 'POST';

        request.requestBody =
            Blob.valueOf(payload);

        request.addHeader(
            'X-Razorpay-Signature',
            signature
        );

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();

        RazorpayWebhookEndpoint.receiveWebhook();

        Test.stopTest();

        System.assertEquals(
            400,
            RestContext.response.statusCode
        );

        System.assert(
            RestContext.response.responseBody
                .toString()
                .contains('"success":false'),
            'Expected failed webhook response.'
        );
    }
}