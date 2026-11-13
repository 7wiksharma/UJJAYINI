public without sharing class RazorpayWebhookService {

    public class WebhookRequest {
        public String eventId;
        public String eventType;
        public String rawPayload;
        public String signature;
    }

    public class WebhookResult {
        public String webhookEventId;
        public String processingStatus;
        public Boolean signatureVerified;
        public Boolean duplicate;
    }

    public class WebhookSecurityException extends Exception {
    }


    /*
     * ============================================================
     * MAIN WEBHOOK PROCESSOR
     * ============================================================
     */
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
         * 2. Extract actual event type from payload.
         */
        String eventType =
            extractEventType(
                request.rawPayload
            );

        /*
         * 3. Extract payment identifiers.
         */
        Map<String, Object> payload =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    request.rawPayload
                );

        Map<String, Object> payloadData =
            getMap(
                payload,
                'payload'
            );

        Map<String, Object> paymentLinkData =
            getMap(
                payloadData,
                'payment_link'
            );

        Map<String, Object> paymentLinkEntity =
            getMap(
                paymentLinkData,
                'entity'
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

        String paymentLinkId =
            getString(
                paymentLinkEntity,
                'id'
            );

        String razorpayPaymentId =
            getString(
                paymentEntity,
                'id'
            );

        /*
         * Payment Link events must contain a Payment Link ID.
         */
        if (String.isBlank(paymentLinkId)) {

            /*
             * For non-Payment-Link events, allow processing
             * to continue because payment.captured,
             * payment.authorized, etc. may use Order ID.
             */
            if (
                eventType == 'payment_link.paid'
            ) {
                throw new IllegalArgumentException(
                    'Razorpay Payment Link ID is missing from webhook payload.'
                );
            }
        }


        /*
         * ========================================================
         * PAYMENT-BASED IDEMPOTENCY
         * ========================================================
         *
         * Payment__c is the business idempotency anchor.
         *
         * Webhook_Event__c remains an audit object.
         */
        Payment__c paymentRecord = null;

        if (!String.isBlank(paymentLinkId)) {

            paymentRecord =
                findPaymentByGatewayIdentifiers(
                    null,
                    null,
                    paymentLinkId
                );
        }

        if (
            paymentRecord == null &&
            !String.isBlank(razorpayPaymentId)
        ) {

            paymentRecord =
                findPaymentByGatewayIdentifiers(
                    razorpayPaymentId,
                    null,
                    null
                );
        }


        /*
         * If we found a payment that is already captured,
         * treat the webhook as an idempotent duplicate.
         */
       if (
    paymentRecord != null &&
    paymentRecord.Payment_Status__c == 'Captured'
) {

    // Payment is already captured.
    // Still ensure downstream fulfillment is completed.
    fulfillOrder(
        paymentRecord.Order__c
    );

    WebhookResult duplicateResult =
        new WebhookResult();

    duplicateResult.webhookEventId =
        null;

    duplicateResult.processingStatus =
        'Processed';

    duplicateResult.signatureVerified =
        true;

    duplicateResult.duplicate =
        true;

    return duplicateResult;
}


        /*
         * ========================================================
         * CREATE WEBHOOK AUDIT RECORD
         * ========================================================
         */
        Webhook_Event__c webhookEvent =
            new Webhook_Event__c();

        webhookEvent.Event_ID__c =
            request.eventId;

        webhookEvent.Event_Type__c =
            mapEventType(eventType);

        webhookEvent.Event_Received_At__c =
            System.now();

        webhookEvent.Processing_Status__c =
            'Received';

        webhookEvent.Raw_Payload__c =
            request.rawPayload;

        webhookEvent.Signature_Verified__c =
            true;

        Database.insert(
            webhookEvent,
            AccessLevel.SYSTEM_MODE
        );


        /*
         * ========================================================
         * PROCESS BUSINESS EVENT
         * ========================================================
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

            Database.update(
                webhookEvent,
                AccessLevel.SYSTEM_MODE
            );

        } catch (Exception e) {

            webhookEvent.Processing_Status__c =
                'Failed';

            webhookEvent.Processing_Error__c =
                e.getMessage();

            Database.update(
                webhookEvent,
                AccessLevel.SYSTEM_MODE
            );

            throw e;
        }


        /*
         * ========================================================
         * RETURN RESULT
         * ========================================================
         */
        WebhookResult result =
            new WebhookResult();

        result.webhookEventId =
            String.valueOf(
                webhookEvent.Id
            );

        result.processingStatus =
            webhookEvent.Processing_Status__c;

        result.signatureVerified =
            webhookEvent.Signature_Verified__c;

        result.duplicate =
            false;

        return result;
    }


    /*
     * ============================================================
     * EVENT DISPATCHER
     * ============================================================
     */
    private static void processBusinessEvent(
        String eventType,
        String rawPayload
    ) {

        if (eventType == 'payment.captured') {

            processPaymentCaptured(
                rawPayload
            );

        } else if (eventType == 'payment_link.paid') {

            processPaymentLinkPaid(
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

            /*
             * Audit only.
             */

        } else {

            /*
             * Unknown events are audit only.
             */

        }
    }


    /*
     * ============================================================
     * PAYMENT CAPTURED
     * ============================================================
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

        if (
            String.isBlank(razorpayPaymentId) &&
            String.isBlank(razorpayOrderId)
        ) {

            throw new IllegalArgumentException(
                'Razorpay Payment ID and Order ID are both missing from payment.captured event.'
            );
        }


        Payment__c payment =
            findPaymentByGatewayIdentifiers(
                razorpayPaymentId,
                razorpayOrderId,
                null
            );

        if (payment == null) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Payment ID: ' +
                razorpayPaymentId +
                ' or Razorpay Order ID: ' +
                razorpayOrderId
            );
        }


        payment.Gateway_Payment_ID__c =
            razorpayPaymentId;

        payment.Payment_Status__c =
            'Captured';

        if (payment.Paid_At__c == null) {

            payment.Paid_At__c =
                System.now();
        }

        Database.update(
            payment,
            AccessLevel.SYSTEM_MODE
        );


        fulfillOrder(
            payment.Order__c
        );
    }


    /*
     * ============================================================
     * PAYMENT LINK PAID
     * ============================================================
     */
    private static void processPaymentLinkPaid(
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

        Map<String, Object> paymentLinkData =
            getMap(
                payloadData,
                'payment_link'
            );

        Map<String, Object> paymentLinkEntity =
            getMap(
                paymentLinkData,
                'entity'
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

        String paymentLinkId =
            getString(
                paymentLinkEntity,
                'id'
            );

        String razorpayPaymentId =
            getString(
                paymentEntity,
                'id'
            );

        if (String.isBlank(paymentLinkId)) {

            throw new IllegalArgumentException(
                'Razorpay Payment Link ID is missing from payment_link.paid event.'
            );
        }

        if (String.isBlank(razorpayPaymentId)) {

            throw new IllegalArgumentException(
                'Razorpay Payment ID is missing from payment_link.paid event.'
            );
        }


        Payment__c payment =
            findPaymentByGatewayIdentifiers(
                null,
                null,
                paymentLinkId
            );

        if (payment == null) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Payment Link ID: ' +
                paymentLinkId
            );
        }


        payment.Gateway_Payment_ID__c =
            razorpayPaymentId;

        payment.Payment_Status__c =
            'Captured';

        if (payment.Paid_At__c == null) {

            payment.Paid_At__c =
                System.now();
        }

        Database.update(
            payment,
            AccessLevel.SYSTEM_MODE
        );


        fulfillOrder(
            payment.Order__c
        );
    }


    /*
     * ============================================================
     * PAYMENT AUTHORIZED
     * ============================================================
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

        if (
            String.isBlank(razorpayPaymentId) &&
            String.isBlank(razorpayOrderId)
        ) {

            throw new IllegalArgumentException(
                'Razorpay Payment ID and Order ID are both missing from payment.authorized event.'
            );
        }


        Payment__c payment =
            findPaymentByGatewayIdentifiers(
                razorpayPaymentId,
                razorpayOrderId,
                null
            );

        if (payment == null) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Payment ID: ' +
                razorpayPaymentId +
                ' or Razorpay Order ID: ' +
                razorpayOrderId
            );
        }


        if (!String.isBlank(razorpayPaymentId)) {

            payment.Gateway_Payment_ID__c =
                razorpayPaymentId;
        }

        payment.Payment_Status__c =
            'Authorized';

        Database.update(
            payment,
            AccessLevel.SYSTEM_MODE
        );
    }


    /*
     * ============================================================
     * PAYMENT FAILED
     * ============================================================
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

        String failureReason =
            getString(
                paymentEntity,
                'error_description'
            );


        if (
            String.isBlank(razorpayPaymentId) &&
            String.isBlank(razorpayOrderId)
        ) {

            throw new IllegalArgumentException(
                'Razorpay Payment ID and Order ID are both missing from payment.failed event.'
            );
        }


        Payment__c payment =
            findPaymentByGatewayIdentifiers(
                razorpayPaymentId,
                razorpayOrderId,
                null
            );

        if (payment == null) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Payment ID: ' +
                razorpayPaymentId +
                ' or Razorpay Order ID: ' +
                razorpayOrderId
            );
        }


        payment.Payment_Status__c =
            'Failed';

        if (!String.isBlank(failureReason)) {

            payment.Failure_Reason__c =
                failureReason;
        }

        Database.update(
            payment,
            AccessLevel.SYSTEM_MODE
        );
    }


    /*
     * ============================================================
     * PAYMENT REFUNDED
     * ============================================================
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


        String refundQuery =
            'SELECT Id, ' +
            'Gateway_Payment_ID__c, ' +
            'Payment_Status__c, ' +
            'Refunded_At__c ' +
            'FROM Payment__c ' +
            'WHERE Gateway_Payment_ID__c = \'' +
            String.escapeSingleQuotes(
                razorpayPaymentId
            ) +
            '\' ' +
            'LIMIT 1';

        List<Payment__c> payments =
            Database.query(
                refundQuery,
                AccessLevel.SYSTEM_MODE
            );


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

        Database.update(
            payment,
            AccessLevel.SYSTEM_MODE
        );
    }


    /*
     * ============================================================
     * ORDER PAID
     * ============================================================
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


        Payment__c payment =
            findPaymentByGatewayIdentifiers(
                null,
                razorpayOrderId,
                null
            );


        if (payment == null) {

            throw new IllegalArgumentException(
                'Payment record not found for Razorpay Order ID: ' +
                razorpayOrderId
            );
        }


        if (
            payment.Payment_Status__c ==
            'Captured'
        ) {

            fulfillOrder(
                payment.Order__c
            );
        }
    }


    /*
     * ============================================================
     * FIND PAYMENT
     * ============================================================
     *
     * Supports:
     *
     * 1. Razorpay Payment ID
     * 2. Salesforce Order ID
     * 3. Razorpay Payment Link ID
     */
    private static Payment__c findPaymentByGatewayIdentifiers(
        String razorpayPaymentId,
        Id orderId,
        String paymentLinkId
    ) {

        /*
         * --------------------------------------------------------
         * 1. RAZORPAY PAYMENT ID
         * --------------------------------------------------------
         */
        if (!String.isBlank(razorpayPaymentId)) {

            String paymentIdQuery =
                'SELECT Id, ' +
                'Order__c, ' +
                'Payment_Status__c, ' +
                'Gateway_Order_ID__c, ' +
                'Gateway_Payment_ID__c, ' +
                'Paid_At__c ' +
                'FROM Payment__c ' +
                'WHERE Gateway_Payment_ID__c = \'' +
                String.escapeSingleQuotes(
                    razorpayPaymentId
                ) +
                '\' ' +
                'LIMIT 1';

            List<Payment__c> payments =
                Database.query(
                    paymentIdQuery,
                    AccessLevel.SYSTEM_MODE
                );

            if (!payments.isEmpty()) {
                return payments[0];
            }
        }


        /*
         * --------------------------------------------------------
         * 2. SALESFORCE ORDER ID
         * --------------------------------------------------------
         */
        if (orderId != null) {

            String orderQuery =
                'SELECT Id, ' +
                'Order__c, ' +
                'Payment_Status__c, ' +
                'Gateway_Order_ID__c, ' +
                'Gateway_Payment_ID__c, ' +
                'Paid_At__c ' +
                'FROM Payment__c ' +
                'WHERE Order__c = \'' +
                String.escapeSingleQuotes(
                    String.valueOf(orderId)
                ) +
                '\' ' +
                'ORDER BY CreatedDate DESC ' +
                'LIMIT 1';

            List<Payment__c> payments =
                Database.query(
                    orderQuery,
                    AccessLevel.SYSTEM_MODE
                );

            if (!payments.isEmpty()) {
                return payments[0];
            }
        }


        /*
         * --------------------------------------------------------
         * 3. RAZORPAY PAYMENT LINK ID
         * --------------------------------------------------------
         */
        if (!String.isBlank(paymentLinkId)) {

            String paymentLinkQuery =
                'SELECT Id, ' +
                'Order__c, ' +
                'Payment_Status__c, ' +
                'Gateway_Order_ID__c, ' +
                'Gateway_Payment_ID__c, ' +
                'Paid_At__c ' +
                'FROM Payment__c ' +
                'WHERE Gateway_Order_ID__c = \'' +
                String.escapeSingleQuotes(
                    paymentLinkId
                ) +
                '\' ' +
                'LIMIT 1';

            List<Payment__c> payments =
                Database.query(
                    paymentLinkQuery,
                    AccessLevel.SYSTEM_MODE
                );

            if (!payments.isEmpty()) {
                return payments[0];
            }
        }

        return null;
    }


    /*
     * ============================================================
     * ORDER FULFILLMENT
     * ============================================================
     */
    private static void fulfillOrder(
        Id orderId
    ) {

        if (orderId == null) {
            return;
        }


        String orderQuery =
            'SELECT Id, ' +
            'Status ' +
            'FROM Order ' +
            'WHERE Id = \'' +
            String.escapeSingleQuotes(
                String.valueOf(orderId)
            ) +
            '\' ' +
            'LIMIT 1';

        List<Order> orders =
            Database.query(
                orderQuery,
                AccessLevel.SYSTEM_MODE
            );


        if (orders.isEmpty()) {

            throw new IllegalArgumentException(
                'Salesforce Order was not found: ' +
                orderId
            );
        }


        Order orderRecord =
            orders[0];


        if (orderRecord.Status == 'Draft') {

            orderRecord.Status =
                'Activated';

            Database.update(
                orderRecord,
                AccessLevel.SYSTEM_MODE
            );
        }


        /*
         * AssetFulfillmentService is idempotent.
         */
        AssetFulfillmentService.FulfillmentResult fulfillmentResult =
            AssetFulfillmentService.createAssetsForOrder(
                orderId
            );
    }


    /*
     * ============================================================
     * SAFE MAP EXTRACTION
     * ============================================================
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
     * ============================================================
     * SAFE STRING EXTRACTION
     * ============================================================
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


    /*
     * ============================================================
     * REQUEST VALIDATION
     * ============================================================
     */
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


    /*
     * ============================================================
     * RAZORPAY SIGNATURE VERIFICATION
     * ============================================================
     */
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
            Blob.valueOf(
                rawPayload
            );

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


    /*
     * ============================================================
     * EVENT TYPE EXTRACTION
     * ============================================================
     */
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


        return String.valueOf(
            eventValue
        );
    }


    /*
     * ============================================================
     * EVENT TYPE MAPPING
     * ============================================================
     */
    private static String mapEventType(
        String eventType
    ) {

        Map<String, String> eventTypeMap =
            new Map<String, String>{

                'payment.authorized'
                    => 'Payment Authorized',

                'payment.captured'
                    => 'Payment Captured',

                'payment_link.paid'
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
            eventTypeMap.containsKey(
                eventType
            )
        ) {

            return eventTypeMap.get(
                eventType
            );
        }


        return 'Other';
    }
}