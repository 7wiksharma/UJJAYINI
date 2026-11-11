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
         * 1. Verify Razorpay signature.
         */
        verifySignature(
            request.rawPayload,
            request.signature
        );

        /*
         * 2. Extract event type.
         */
        String eventType =
            extractEventType(request.rawPayload);

        /*
         * 3. Idempotency check.
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
         * 4. Create webhook audit record.
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


        /*
         * 5. Process the business event.
         */
        try {

            processBusinessEvent(
                eventType,
                request.rawPayload
            );

            webhookEvent.Processing_Status__c =
                'Processed';

            webhookEvent.Processed_At__c =
                System.now();

            update webhookEvent;

        } catch (Exception e) {

            webhookEvent.Processing_Status__c =
                'Failed';

            webhookEvent.Processing_Error__c =
                e.getMessage();

            update webhookEvent;

            throw e;
        }


        /*
         * 6. Return result.
         */
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


    /*
     * Process supported Razorpay events.
     */
    private static void processBusinessEvent(
        String eventType,
        String rawPayload
    ) {

        if (eventType == 'payment.captured') {

            processPaymentCaptured(
                rawPayload
            );

        } else if (eventType == 'payment.failed') {

            processPaymentFailed(
                rawPayload
            );

        } else if (eventType == 'payment.authorized') {

            processPaymentAuthorized(
                rawPayload
            );

        } else if (eventType == 'payment.refunded') {

            processPaymentRefunded(
                rawPayload
            );

        } else if (eventType == 'order.paid') {

            processOrderPaid(
                rawPayload
            );

        } else if (eventType == 'refund.failed') {

            // No payment state transition yet.
            // Event is still recorded for audit.

        } else {

            // Unknown events are recorded as Other.
            // No business action is performed.
        }
    }


    /*
     * payment.captured
     *
     * Extract Razorpay order ID and payment ID,
     * find the Salesforce Payment__c record,
     * mark it Captured,
     * activate the Salesforce Order,
     * then create Assets for the purchased Order Items.
     */
    private static void processPaymentCaptured(
        String rawPayload
    ) {

        Map<String, Object> payload =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    rawPayload
                );

        Map<String, Object> payloadData =
            getMap(
                payload,
                'payload'
            );

        Map<String, Object> paymentData =
            getMap(
                payloadData,
                'payment'
            );

        Map<String, Object> paymentEntity =
            getMap(
                paymentData,
                'entity'
            );

        Map<String, Object> orderData =
            getMap(
                payloadData,
                'order'
            );

        Map<String, Object> orderEntity =
            getMap(
                orderData,
                'entity'
            );

        String razorpayPaymentId =
            getString(
                paymentEntity,
                'id'
            );

        String razorpayOrderId =
            getString(
                orderEntity,
                'id'
            );

        if (String.isBlank(razorpayOrderId)) {

            throw new IllegalArgumentException(
                'Razorpay order ID is missing from payment.captured event.'
            );
        }

        if (String.isBlank(razorpayPaymentId)) {

            throw new IllegalArgumentException(
                'Razorpay payment ID is missing from payment.captured event.'
            );
        }


        /*
         * Find Salesforce Payment.
         */
        List<Payment__c> payments = [
            SELECT Id,
                   Order__c,
                   Amount__c,
                   Payment_Status__c,
                   Gateway_Order_ID__c,
                   Gateway_Payment_ID__c,
                   Paid_At__c
            FROM Payment__c
            WHERE Gateway_Order_ID__c =
                :razorpayOrderId
            LIMIT 1
        ];

        if (payments.isEmpty()) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Order ID: ' +
                razorpayOrderId
            );
        }

        Payment__c payment =
            payments[0];


        /*
         * Idempotent payment state update.
         */
        payment.Gateway_Payment_ID__c =
            razorpayPaymentId;

        payment.Payment_Status__c =
            'Captured';

        payment.Paid_At__c =
            System.now();

        update payment;


        /*
         * Activate the related Salesforce Order.
         */
        if (payment.Order__c != null) {

            Order orderRecord = [
                SELECT Id,
                       Status
                FROM Order
                WHERE Id = :payment.Order__c
                LIMIT 1
            ];

            if (orderRecord.Status == 'Draft') {

                orderRecord.Status =
                    'Activated';

                update orderRecord;
            }


            /*
             * Fulfill the activated Order.
             *
             * This creates Salesforce Assets
             * for the purchased Order Items.
             */
            AssetFulfillmentService.FulfillmentResult fulfillmentResult =
                AssetFulfillmentService.createAssetsForOrder(
                    payment.Order__c
                );
        }
    }


    /*
     * payment.authorized
     */
    private static void processPaymentAuthorized(
        String rawPayload
    ) {

        Map<String, Object> payload =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    rawPayload
                );

        Map<String, Object> payloadData =
            getMap(
                payload,
                'payload'
            );

        Map<String, Object> paymentData =
            getMap(
                payloadData,
                'payment'
            );

        Map<String, Object> paymentEntity =
            getMap(
                paymentData,
                'entity'
            );

        Map<String, Object> orderData =
            getMap(
                payloadData,
                'order'
            );

        Map<String, Object> orderEntity =
            getMap(
                orderData,
                'entity'
            );

        String razorpayPaymentId =
            getString(
                paymentEntity,
                'id'
            );

        String razorpayOrderId =
            getString(
                orderEntity,
                'id'
            );

        if (String.isBlank(razorpayOrderId)) {

            throw new IllegalArgumentException(
                'Razorpay order ID is missing from payment.authorized event.'
            );
        }

        List<Payment__c> payments = [
            SELECT Id,
                   Gateway_Order_ID__c,
                   Gateway_Payment_ID__c,
                   Payment_Status__c
            FROM Payment__c
            WHERE Gateway_Order_ID__c =
                :razorpayOrderId
            LIMIT 1
        ];

        if (payments.isEmpty()) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Order ID: ' +
                razorpayOrderId
            );
        }

        Payment__c payment =
            payments[0];

        payment.Gateway_Payment_ID__c =
            razorpayPaymentId;

        payment.Payment_Status__c =
            'Authorized';

        update payment;
    }


    /*
     * payment.failed
     */
    private static void processPaymentFailed(
        String rawPayload
    ) {

        Map<String, Object> payload =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    rawPayload
                );

        Map<String, Object> payloadData =
            getMap(
                payload,
                'payload'
            );

        Map<String, Object> paymentData =
            getMap(
                payloadData,
                'payment'
            );

        Map<String, Object> paymentEntity =
            getMap(
                paymentData,
                'entity'
            );

        Map<String, Object> orderData =
            getMap(
                payloadData,
                'order'
            );

        Map<String, Object> orderEntity =
            getMap(
                orderData,
                'entity'
            );

        String razorpayOrderId =
            getString(
                orderEntity,
                'id'
            );

        String failureReason =
            getString(
                paymentEntity,
                'error_description'
            );

        if (String.isBlank(razorpayOrderId)) {

            throw new IllegalArgumentException(
                'Razorpay order ID is missing from payment.failed event.'
            );
        }

        List<Payment__c> payments = [
            SELECT Id,
                   Gateway_Order_ID__c,
                   Payment_Status__c,
                   Failure_Reason__c
            FROM Payment__c
            WHERE Gateway_Order_ID__c =
                :razorpayOrderId
            LIMIT 1
        ];

        if (payments.isEmpty()) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Order ID: ' +
                razorpayOrderId
            );
        }

        Payment__c payment =
            payments[0];

        payment.Payment_Status__c =
            'Failed';

        if (!String.isBlank(failureReason)) {

            payment.Failure_Reason__c =
                failureReason;
        }

        update payment;
    }


    /*
     * payment.refunded
     */
    private static void processPaymentRefunded(
        String rawPayload
    ) {

        Map<String, Object> payload =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    rawPayload
                );

        Map<String, Object> payloadData =
            getMap(
                payload,
                'payload'
            );

        Map<String, Object> paymentData =
            getMap(
                payloadData,
                'payment'
            );

        Map<String, Object> paymentEntity =
            getMap(
                paymentData,
                'entity'
            );

        String razorpayPaymentId =
            getString(
                paymentEntity,
                'id'
            );

        if (String.isBlank(razorpayPaymentId)) {

            throw new IllegalArgumentException(
                'Razorpay payment ID is missing from payment.refunded event.'
            );
        }

        List<Payment__c> payments = [
            SELECT Id,
                   Gateway_Payment_ID__c,
                   Payment_Status__c,
                   Refunded_At__c
            FROM Payment__c
            WHERE Gateway_Payment_ID__c =
                :razorpayPaymentId
            LIMIT 1
        ];

        if (payments.isEmpty()) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Payment ID: ' +
                razorpayPaymentId
            );
        }

        Payment__c payment =
            payments[0];

        payment.Payment_Status__c =
            'Refunded';

        payment.Refunded_At__c =
            System.now();

        update payment;
    }


    /*
     * order.paid
     *
     * The payment.captured event is the main
     * Payment__c state transition.
     *
     * For order.paid we activate the related
     * Salesforce Order if the Payment is already captured.
     */
    private static void processOrderPaid(
        String rawPayload
    ) {

        Map<String, Object> payload =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    rawPayload
                );

        Map<String, Object> payloadData =
            getMap(
                payload,
                'payload'
            );

        Map<String, Object> orderData =
            getMap(
                payloadData,
                'order'
            );

        Map<String, Object> orderEntity =
            getMap(
                orderData,
                'entity'
            );

        String razorpayOrderId =
            getString(
                orderEntity,
                'id'
            );

        if (String.isBlank(razorpayOrderId)) {

            throw new IllegalArgumentException(
                'Razorpay order ID is missing from order.paid event.'
            );
        }

        List<Payment__c> payments = [
            SELECT Id,
                   Order__c,
                   Payment_Status__c,
                   Gateway_Order_ID__c
            FROM Payment__c
            WHERE Gateway_Order_ID__c =
                :razorpayOrderId
            LIMIT 1
        ];

        if (payments.isEmpty()) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Order ID: ' +
                razorpayOrderId
            );
        }

        Payment__c payment =
            payments[0];

        if (
            payment.Payment_Status__c ==
            'Captured'
        ) {

            if (payment.Order__c != null) {

                Order orderRecord = [
                    SELECT Id,
                           Status
                    FROM Order
                    WHERE Id = :payment.Order__c
                    LIMIT 1
                ];

                if (orderRecord.Status == 'Draft') {

                    orderRecord.Status =
                        'Activated';

                    update orderRecord;
                }
            }
        }
    }


    /*
     * Safe map extraction helper.
     */
    private static Map<String, Object> getMap(
        Map<String, Object> parent,
        String key
    ) {

        if (parent == null) {
            return new Map<String, Object>();
        }

        Object value =
            parent.get(key);

        if (value == null) {
            return new Map<String, Object>();
        }

        return (Map<String, Object>) value;
    }


    /*
     * Safe string extraction helper.
     */
    private static String getString(
        Map<String, Object> parent,
        String key
    ) {

        if (parent == null) {
            return null;
        }

        Object value =
            parent.get(key);

        return value == null
            ? null
            : String.valueOf(value);
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

        if (
            settings == null ||
            String.isBlank(
                settings.Razorpay_Webhook_Secret__c
            )
        ) {

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

        if (
            expectedSignature.toLowerCase() !=
            receivedSignature.toLowerCase()
        ) {

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

        if (
            eventValue == null ||
            String.isBlank(
                String.valueOf(eventValue)
            )
        ) {

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

        if (
            eventTypeMap.containsKey(eventType)
        ) {

            return eventTypeMap.get(
                eventType
            );
        }

        return 'Other';
    }
}