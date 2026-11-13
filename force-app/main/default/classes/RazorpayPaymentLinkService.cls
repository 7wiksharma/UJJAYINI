public with sharing class RazorpayPaymentLinkService {

    public class PaymentLinkRequest {
        public Id orderId;
    }

    public class PaymentLinkResult {
        public Id orderId;
        public Id paymentId;
        public String paymentLinkId;
        public String paymentUrl;
        public Decimal amount;
        public String status;
    }

    public static PaymentLinkResult createPaymentLink(
        PaymentLinkRequest request
    ) {

        if (request == null || request.orderId == null) {
            throw new IllegalArgumentException(
                'Order ID is required.'
            );
        }

        /*
         * Get Order.
         */
        Order orderRecord = [
            SELECT Id,
                   Status,
                   AccountId
            FROM Order
            WHERE Id = :request.orderId
            LIMIT 1
        ];

        if (orderRecord.Status != 'Draft') {
            throw new IllegalArgumentException(
                'Only Draft Orders can create a payment link.'
            );
        }

        if (orderRecord.AccountId == null) {
            throw new IllegalArgumentException(
                'Order Account is required.'
            );
        }

        /*
         * Get Order Items.
         */
        List<OrderItem> orderItems = [
            SELECT Id,
                   Product2Id,
                   Quantity,
                   UnitPrice,
                   TotalPrice
            FROM OrderItem
            WHERE OrderId = :orderRecord.Id
        ];

        if (orderItems.isEmpty()) {
            throw new IllegalArgumentException(
                'Order must contain at least one product.'
            );
        }

        /*
         * Calculate total.
         */
        Decimal totalAmount = 0;

        for (OrderItem item : orderItems) {

            if (item.Product2Id == null) {
                throw new IllegalArgumentException(
                    'Every Order Item must have a Product.'
                );
            }

            if (item.Quantity == null || item.Quantity <= 0) {
                throw new IllegalArgumentException(
                    'Order Item quantity must be greater than zero.'
                );
            }

            if (item.UnitPrice == null || item.UnitPrice < 0) {
                throw new IllegalArgumentException(
                    'Order Item price cannot be negative.'
                );
            }

            if (item.TotalPrice == null || item.TotalPrice < 0) {
                throw new IllegalArgumentException(
                    'Order Item total price cannot be negative.'
                );
            }

            totalAmount += item.TotalPrice;
        }

        if (totalAmount <= 0) {
            throw new IllegalArgumentException(
                'Order total must be greater than zero.'
            );
        }

        /*
         * Get Contact from the Order's Account.
         *
         * We intentionally do NOT use UserInfo.getUserId().
         * This allows the service to work from:
         *
         * - Experience Cloud
         * - Anonymous Apex
         * - Admin execution
         * - future backend automation
         */
        List<Contact> contacts = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Email,
                   Phone,
                   AccountId
            FROM Contact
            WHERE AccountId = :orderRecord.AccountId
            AND Email != null
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            throw new IllegalArgumentException(
                'No customer Contact with an email address was found for the Order Account.'
            );
        }

        Contact customer = contacts[0];

        /*
         * Convert INR to paise.
         *
         * ₹49,999 -> 4,999,900 paise
         */
        Long amountInPaise =
            (totalAmount * 100).longValue();

        /*
         * Build Payment Link payload.
         */
        Map<String, Object> payload =
            new Map<String, Object>();

        payload.put(
            'amount',
            amountInPaise
        );

        payload.put(
            'currency',
            'INR'
        );

        payload.put(
            'accept_partial',
            false
        );

      payload.put(
    'reference_id',
    String.valueOf(orderRecord.Id) +
    '-' +
    String.valueOf(DateTime.now().getTime())
);

        payload.put(
            'description',
            'UJJAYINI Order Payment'
        );

        /*
         * Customer information.
         */
        Map<String, Object> customerPayload =
            new Map<String, Object>();

        String customerName =
            ((customer.FirstName == null)
                ? ''
                : customer.FirstName) +
            ' ' +
            ((customer.LastName == null)
                ? ''
                : customer.LastName);

        customerName =
            customerName.trim();

        if (String.isBlank(customerName)) {
            customerName = 'UJJAYINI Customer';
        }

        customerPayload.put(
            'name',
            customerName
        );

        customerPayload.put(
            'email',
            customer.Email
        );

        if (!String.isBlank(customer.Phone)) {
            customerPayload.put(
                'contact',
                customer.Phone
            );
        }

        payload.put(
            'customer',
            customerPayload
        );

        /*
         * UJJAYINI metadata.
         */
        Map<String, Object> notes =
            new Map<String, Object>();

        notes.put(
            'order_id',
            String.valueOf(orderRecord.Id)
        );

        notes.put(
            'source',
            'UJJAYINI'
        );

        payload.put(
            'notes',
            notes
        );

        /*
         * Call Razorpay Payment Link API.
         */
        HttpRequest httpRequest =
            new HttpRequest();

        httpRequest.setEndpoint(
            'callout:Razorpay_API/v1/payment_links'
        );

        httpRequest.setMethod('POST');

        httpRequest.setHeader(
            'Content-Type',
            'application/json'
        );

        httpRequest.setBody(
            JSON.serialize(payload)
        );

        httpRequest.setTimeout(30000);

        Http http = new Http();

        HttpResponse response =
            http.send(httpRequest);

        /*
         * Validate response.
         */
        Integer statusCode =
            response.getStatusCode();

        if (statusCode < 200 || statusCode >= 300) {

            throw new IllegalArgumentException(
                'Razorpay Payment Link creation failed. ' +
                'HTTP ' +
                statusCode +
                ': ' +
                response.getBody()
            );
        }

        Map<String, Object> responseBody =
            (Map<String, Object>)
                JSON.deserializeUntyped(
                    response.getBody()
                );

        String paymentLinkId =
            (String) responseBody.get('id');

        String paymentUrl =
            (String) responseBody.get('short_url');

        if (String.isBlank(paymentLinkId)) {
            throw new IllegalArgumentException(
                'Razorpay did not return a Payment Link ID.'
            );
        }

        if (String.isBlank(paymentUrl)) {
            throw new IllegalArgumentException(
                'Razorpay did not return a Payment Link URL.'
            );
        }

        /*
         * Create Payment__c.
         */
        Payment__c payment =
            new Payment__c(
                Order__c = orderRecord.Id,
                Amount__c = totalAmount,
                Payment_Status__c = 'Pending',
                Gateway_Order_ID__c = paymentLinkId
            );

        insert payment;

        /*
         * Return result.
         */
        PaymentLinkResult result =
            new PaymentLinkResult();

        result.orderId =
            orderRecord.Id;

        result.paymentId =
            payment.Id;

        result.paymentLinkId =
            paymentLinkId;

        result.paymentUrl =
            paymentUrl;

        result.amount =
            totalAmount;

        result.status =
            'PAYMENT_LINK_CREATED';

        return result;
    }
}