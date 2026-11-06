public with sharing class RazorpayWebhookService {

    public class WebhookRequest {
        public String eventId;
        public String eventType;
        public String rawPayload;
        public String signature;
    }

    public class WebhookResult {
        public Id webhookEventId;
        public String processingStatus;
        public Boolean signatureVerified;
        public Boolean duplicate;
    }

    public class WebhookSecurityException extends Exception {
    }

    public static WebhookResult processWebhook(
        WebhookRequest request
    ) {

        validateRequest(request);

        /*
         * 1. Verify the Razorpay webhook signature
         *    against the raw request body.
         */
        verifySignature(
            request.rawPayload,
            request.signature
        );

        /*
         * 2. Extract the event type directly
         *    from the Razorpay payload.
         */
        String eventType =
            extractEventType(request.rawPayload);

        /*
         * 3. Check whether this webhook event
         *    has already been received.
         */
        List<Webhook_Event__c> existingEvents = [
            SELECT Id,
                   Event_ID__c,
                   Processing_Status__c,
                   Signature_Verified__c
            FROM Webhook_Event__c
            WHERE Event_ID__c = :request.eventId
            LIMIT 1
        ];

        if (!existingEvents.isEmpty()) {

            Webhook_Event__c existingEvent =
                existingEvents[0];

            WebhookResult duplicateResult =
                new WebhookResult();

            duplicateResult.webhookEventId =
                existingEvent.Id;

            duplicateResult.processingStatus =
                existingEvent.Processing_Status__c;

            duplicateResult.signatureVerified =
                existingEvent.Signature_Verified__c;

            duplicateResult.duplicate = true;

            return duplicateResult;
        }

        /*
         * 4. Create the webhook audit record.
         */
        Webhook_Event__c webhookEvent =
            new Webhook_Event__c(
                Event_ID__c =
                    request.eventId,

                Event_Type__c =
                    mapEventType(eventType),

                Event_Received_At__c =
                    System.now(),

                Processing_Status__c =
                    'Received',

                Raw_Payload__c =
                    request.rawPayload,

                Signature_Verified__c =
                    true
            );

        insert webhookEvent;

        WebhookResult result =
            new WebhookResult();

        result.webhookEventId =
            webhookEvent.Id;

        result.processingStatus =
            webhookEvent.Processing_Status__c;

        result.signatureVerified =
            webhookEvent.Signature_Verified__c;

        result.duplicate = false;

        return result;
    }


    private static void validateRequest(
        WebhookRequest request
    ) {

        if (request == null) {
            throw new IllegalArgumentException(
                'Webhook request is required.'
            );
        }

        if (String.isBlank(request.eventId)) {
            throw new IllegalArgumentException(
                'Webhook event ID is required.'
            );
        }

        if (String.isBlank(request.rawPayload)) {
            throw new IllegalArgumentException(
                'Webhook raw payload is required.'
            );
        }

        if (String.isBlank(request.signature)) {
            throw new WebhookSecurityException(
                'Webhook signature is required.'
            );
        }
    }


    private static void verifySignature(
        String rawPayload,
        String receivedSignature
    ) {

        UJJAYINI_Integration_Settings__c settings =
            UJJAYINI_Integration_Settings__c.getOrgDefaults();

        if (settings == null ||
            String.isBlank(
                settings.Razorpay_Webhook_Secret__c
            )) {

            throw new WebhookSecurityException(
                'Razorpay webhook secret is not configured.'
            );
        }

        Blob payloadBlob =
            Blob.valueOf(rawPayload);

        Blob secretBlob =
            Blob.valueOf(
                settings.Razorpay_Webhook_Secret__c
            );

        Blob generatedSignature =
            Crypto.generateMac(
                'HmacSHA256',
                payloadBlob,
                secretBlob
            );

        String expectedSignature =
            EncodingUtil.convertToHex(
                generatedSignature
            );

        if (expectedSignature.toLowerCase() !=
            receivedSignature.toLowerCase()) {

            throw new WebhookSecurityException(
                'Invalid Razorpay webhook signature.'
            );
        }
    }


    private static String extractEventType(
        String rawPayload
    ) {

        Map<String, Object> payload =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    rawPayload
                );

        Object eventValue =
            payload.get('event');

        if (eventValue == null ||
            String.isBlank(
                String.valueOf(eventValue)
            )) {

            throw new IllegalArgumentException(
                'Webhook event type is missing.'
            );
        }

        return String.valueOf(eventValue);
    }


    private static String mapEventType(
        String eventType
    ) {

        Map<String, String> eventTypeMap =
            new Map<String, String>{
                'payment.authorized'
                    => 'Payment Authorized',

                'payment.captured'
                    => 'Payment Captured',

                'payment.failed'
                    => 'Payment Failed',

                'payment.refunded'
                    => 'Payment Refunded',

                'refund.failed'
                    => 'Payment Refund Failed',

                'order.paid'
                    => 'Order Paid'
            };

        if (eventTypeMap.containsKey(eventType)) {
            return eventTypeMap.get(eventType);
        }

        return 'Other';
    }
}