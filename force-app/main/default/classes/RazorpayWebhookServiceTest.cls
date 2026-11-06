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

        settings.Name = 'UJJAYINI Integration Settings';

        settings.Razorpay_Webhook_Secret__c =
            webhookSecret;

        insert settings;
    }


    @IsTest
    static void processesValidWebhook() {

        createWebhookSettings();

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

        System.assertNotEquals(
            null,
            result.webhookEventId
        );

        System.assertEquals(
            'Received',
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
            'Received',
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

        request.signature = null;

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

        System.assertEquals(
            false,
            firstResult.duplicate
        );

        System.assertEquals(
            true,
            secondResult.duplicate
        );

        System.assertEquals(
            firstResult.webhookEventId,
            secondResult.webhookEventId
        );

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Webhook_Event__c
                WHERE Event_ID__c = 'evt_test_duplicate'
            ]
        );
    }
}