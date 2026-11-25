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

    // Point to the audit record of the first delivery.
    duplicateResult.webhookEventId =
        existingWebhookEventId(request.eventId);

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

        // SHA-256 fingerprint of the exact body Razorpay sent.
        webhookEvent.Payload_Hash__c =
            EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(request.rawPayload))
            );

        // Link the audit record to our Payment, when we know it.
        if (paymentRecord != null) {
            webhookEvent.Related_Payment__c = paymentRecord.Id;
        }

        Database.insert(
            webhookEvent,
            AccessLevel.SYSTEM_MODE
        );

        // Remember it, so a repeat delivery in this same
        // transaction can point back to it.
        RECEIVED_EVENTS.put(request.eventId, String.valueOf(webhookEvent.Id));


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

            // Payment found only now (e.g. the first event of a
            // payment): link the audit record to it.
            if (webhookEvent.Related_Payment__c == null) {
                Payment__c linkedPayment = null;
                if (!String.isBlank(paymentLinkId)) {
                    linkedPayment = findPaymentByGatewayIdentifiers(null, null, paymentLinkId);
                }
                if (linkedPayment == null && !String.isBlank(razorpayPaymentId)) {
                    linkedPayment = findPaymentByGatewayIdentifiers(razorpayPaymentId, null, null);
                }
                if (linkedPayment == null) {
                    // e.g. payment.failed: matched through the order id in the notes
                    linkedPayment = findOpenPaymentForOrder(
                        getString(getMap(paymentEntity, 'notes'), 'order_id')
                    );
                }
                if (linkedPayment != null) {
                    webhookEvent.Related_Payment__c = linkedPayment.Id;
                }
            }

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

        } else if (
            eventType == 'payment_link.expired' ||
            eventType == 'payment_link.cancelled'
        ) {

            processPaymentLinkClosed(
                eventType,
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
                null,
                razorpayOrderId // a Razorpay id is text, never a Salesforce Id
            );

        if (payment == null) {
            /*
             * For a Payment Link payment, payment.captured can arrive
             * BEFORE payment_link.paid, when our Payment__c does not
             * know this Razorpay payment id yet. payment_link.paid
             * completes the order. Throwing here made the webhook
             * answer HTTP 400, and Razorpay disables a webhook that
             * keeps failing. So we simply acknowledge it.
             */
            System.debug(
                LoggingLevel.WARN,
                'UJJAYINI: payment.captured with no matching Payment__c yet: ' +
                razorpayPaymentId
            );
            return;
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

        // UPI / card / net banking etc., from Razorpay's payment.
        String method = paymentMethodLabel(paymentEntity);
        if (method != null) {
            payment.Payment_Method__c = method;
        }

        // Paid now: clear the reason of any earlier failed attempt.
        payment.Failure_Reason__c = null;

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
                null,
                razorpayOrderId // a Razorpay id is text, never a Salesforce Id
            );

        if (payment == null) {
            /*
             * Same as payment.captured: for a Payment Link payment
             * this event can arrive before payment_link.paid.
             * Acknowledge it instead of answering HTTP 400.
             */
            return;
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
            (Map<String, Object>) JSON.deserializeUntyped(rawPayload);

        Map<String, Object> paymentEntity =
            getMap(getMap(getMap(payload, 'payload'), 'payment'), 'entity');

        String razorpayPaymentId = getString(paymentEntity, 'id');

        String failureReason = getString(paymentEntity, 'error_description');

        /*
         * Find our Payment__c:
         * 1. by the Razorpay payment id (if we already know it), or
         * 2. by the Salesforce Order Id we put in the link's notes
         *    (Razorpay copies the link notes onto its payments).
         */
        Payment__c payment = null;

        if (!String.isBlank(razorpayPaymentId)) {
            payment = findPaymentByGatewayIdentifiers(razorpayPaymentId, null, null);
        }

        if (payment == null) {
            payment = findOpenPaymentForOrder(
                getString(getMap(paymentEntity, 'notes'), 'order_id')
            );
        }

        if (payment == null || payment.Payment_Status__c == 'Captured') {
            // Not ours, or already paid by a later attempt: nothing to change.
            return;
        }

        /*
         * The customer may still retry on the same link. If a later
         * attempt succeeds, payment_link.paid sets it to Captured.
         */
        payment.Payment_Status__c = 'Failed';

        payment.Failure_Reason__c = String.isBlank(failureReason)
            ? 'The payment attempt was declined.'
            : failureReason.left(255);

        String method = paymentMethodLabel(paymentEntity);
        if (method != null) {
            payment.Payment_Method__c = method;
        }

        Database.update(payment, AccessLevel.SYSTEM_MODE);
    }


    /*
     * ============================================================
     * PAYMENT LINK EXPIRED / CANCELLED
     *
     * The customer never paid within the link's validity.
     * (The stock hold is released by the reservation expiry job.)
     * ============================================================
     */
    private static void processPaymentLinkClosed(
        String eventType,
        String rawPayload
    ) {

        Map<String, Object> payload =
            (Map<String, Object>) JSON.deserializeUntyped(rawPayload);

        String paymentLinkId = getString(
            getMap(getMap(getMap(payload, 'payload'), 'payment_link'), 'entity'),
            'id'
        );

        if (String.isBlank(paymentLinkId)) {
            return;
        }

        Payment__c payment =
            findPaymentByGatewayIdentifiers(null, null, paymentLinkId);

        if (payment == null || payment.Payment_Status__c == 'Captured') {
            return;
        }

        payment.Payment_Status__c = 'Failed';

        payment.Failure_Reason__c = eventType == 'payment_link.expired'
            ? 'The payment link expired before payment was completed.'
            : 'The payment link was cancelled.';

        Database.update(payment, AccessLevel.SYSTEM_MODE);
    }


    /*
     * Latest unpaid Payment__c of a Salesforce Order.
     * The value comes from Razorpay notes, so it is checked first.
     */
    private static Payment__c findOpenPaymentForOrder(
        String salesforceOrderId
    ) {

        if (String.isBlank(salesforceOrderId)
            || !Pattern.matches('[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?', salesforceOrderId)) {
            return null;
        }

        Id orderId = Id.valueOf(salesforceOrderId);

        List<Payment__c> payments = [
            SELECT Id, Order__c, Payment_Status__c, Gateway_Order_ID__c,
                   Gateway_Payment_ID__c, Paid_At__c
            FROM Payment__c
            WHERE Order__c = :orderId
            AND Payment_Status__c != 'Captured'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return payments.isEmpty() ? null : payments[0];
    }


    /*
     * Razorpay "method" -> our Payment_Method__c picklist value.
     */
    private static String paymentMethodLabel(
        Map<String, Object> paymentEntity
    ) {

        String method = getString(paymentEntity, 'method');

        if (String.isBlank(method)) {
            return null;
        }

        method = method.toLowerCase();

        if (method == 'upi') { return 'UPI'; }
        if (method == 'netbanking') { return 'Net Banking'; }
        if (method == 'wallet') { return 'Wallet'; }
        if (method == 'emi' || method == 'cardless_emi') { return 'EMI'; }

        if (method == 'card') {
            String cardType = getString(getMap(paymentEntity, 'card'), 'type');
            if (cardType == 'credit') { return 'Credit Card'; }
            if (cardType == 'debit') { return 'Debit Card'; }
        }

        return 'Other';
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
            (Map<String, Object>) JSON.deserializeUntyped(rawPayload);

        Map<String, Object> orderEntity =
            getMap(getMap(getMap(payload, 'payload'), 'order'), 'entity');

        String razorpayOrderId = getString(orderEntity, 'id');

        if (String.isBlank(razorpayOrderId)) {
            return;
        }

        /*
         * The Razorpay order id ("order_...") is TEXT. The old code
         * passed it into a Salesforce Id parameter, which failed
         * with "Invalid id" and made the webhook answer HTTP 400.
         * It is now matched against Gateway_Order_ID__c as text.
         *
         * For Payment Link payments there is usually no match:
         * payment_link.paid completes the order, so we just
         * acknowledge the event.
         */
        Payment__c payment =
            findPaymentByGatewayIdentifiers(null, null, razorpayOrderId);

        if (payment != null && payment.Payment_Status__c == 'Captured') {
            fulfillOrder(payment.Order__c);
        }
    }


    /*
     * Audit record of an event already received (same Event ID),
     * so a duplicate delivery can point back to it.
     */
    private static final Map<String, String> RECEIVED_EVENTS =
        new Map<String, String>();

    private static String existingWebhookEventId(
        String eventId
    ) {

        if (String.isBlank(eventId)) {
            return null;
        }

        if (RECEIVED_EVENTS.containsKey(eventId)) {
            return RECEIVED_EVENTS.get(eventId);
        }

        List<Webhook_Event__c> events = [
            SELECT Id
            FROM Webhook_Event__c
            WHERE Event_ID__c = :eventId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        return events.isEmpty() ? null : String.valueOf(events[0].Id);
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
    /*
     * ============================================================
     * FALLBACK: CONFIRM A PAID PAYMENT LINK DIRECTLY
     *
     * Used by the Collector's Vault when the customer is back but
     * the webhook has not arrived yet (or failed). We ASK Razorpay
     * for the link status. Callout first, DML after.
     *
     * Safe together with the webhook: fulfilment is idempotent,
     * so whichever runs first wins.
     * Returns true when Razorpay says the link is paid.
     * ============================================================
     */
    public static Boolean confirmPaidPaymentLink(
        String paymentLinkId
    ) {

        if (String.isBlank(paymentLinkId)) {
            return false;
        }

        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint(
            'callout:Razorpay_API/v1/payment_links/' +
            EncodingUtil.urlEncode(paymentLinkId, 'UTF-8')
        );
        httpRequest.setMethod('GET');
        httpRequest.setTimeout(20000);

        HttpResponse response = new Http().send(httpRequest);

        if (response.getStatusCode() != 200) {
            return false;
        }

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

        if ((String) body.get('status') != 'paid') {
            return false;
        }

        String razorpayPaymentId;
        String paidMethod;
        Object rawPayments = body.get('payments');

        if (rawPayments instanceof List<Object>) {
            for (Object item : (List<Object>) rawPayments) {
                Map<String, Object> linkPayment = (Map<String, Object>) item;
                if ((String) linkPayment.get('status') == 'captured') {
                    razorpayPaymentId = (String) linkPayment.get('payment_id');
                    paidMethod = paymentMethodLabel(linkPayment);
                    break;
                }
            }
        }

        Payment__c payment =
            findPaymentByGatewayIdentifiers(null, null, paymentLinkId);

        if (payment == null) {
            return false;
        }

        if (payment.Payment_Status__c != 'Captured') {

            if (String.isNotBlank(razorpayPaymentId)) {
                payment.Gateway_Payment_ID__c = razorpayPaymentId;
            }

            payment.Payment_Status__c = 'Captured';
            payment.Failure_Reason__c = null;

            if (paidMethod != null) {
                payment.Payment_Method__c = paidMethod;
            }

            if (payment.Paid_At__c == null) {
                payment.Paid_At__c = System.now();
            }

            Database.update(payment, AccessLevel.SYSTEM_MODE);
        }

        fulfillOrder(payment.Order__c);

        return true;
    }


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


        /*
         * Paid stock leaves the shelf: the hold becomes Confirmed
         * and On_Hand goes down. Idempotent, so duplicate or
         * retried webhooks never deduct twice.
         */
        InventoryReservationService.confirmReservationsForOrder(
            orderId
        );
        /*
         * Email the invoice once (idempotent and never fails
         * the webhook).
         */
        OrderInvoiceService.sendInvoiceEmailSafely(
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

        if (!(value instanceof Map<String, Object>)) {
            // null, or Razorpay's empty "notes": [] list
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

                'payment_link.expired'
                    => 'Payment Failed',

                'payment_link.cancelled'
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