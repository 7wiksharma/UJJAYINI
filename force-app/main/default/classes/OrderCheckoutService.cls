public with sharing class OrderCheckoutService {

    public class CheckoutRequest {
        public Id orderId;
        public String paymentMethod;
    }

  public class CheckoutResult {
    @AuraEnabled public Id orderId;
    @AuraEnabled public Id paymentId;
    @AuraEnabled public Id reservationId;
    @AuraEnabled public String gatewayOrderId;
    @AuraEnabled public String status;
    @AuraEnabled public String message;
}

    public static CheckoutResult checkout(
        CheckoutRequest request
    ) {

        if (request == null || request.orderId == null) {
            throw new IllegalArgumentException(
                'Order ID is required.'
            );
        }

        /*
         * STEP 1:
         * Load Order.
         */
        Order orderRecord = [
            SELECT Id,
                   Status,
                   AccountId,
                   EffectiveDate,
                   Pricebook2Id
            FROM Order
            WHERE Id = :request.orderId
            LIMIT 1
        ];

        if (orderRecord.Status != 'Draft') {
            throw new IllegalArgumentException(
                'Only Draft Orders can be checked out.'
            );
        }

        /*
         * STEP 2:
         * Load Order Items.
         */
        List<OrderItem> orderItems = [
            SELECT Id,
                   OrderId,
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
         * STEP 3:
         * Validate Order Items
         * and calculate total.
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
         * STEP 4:
         * Create Razorpay payment order.
         *
         * This performs the HTTP callout.
         * It must happen before inventory DML.
         */
        PaymentService.PaymentRequest paymentRequest =
            new PaymentService.PaymentRequest();

        paymentRequest.orderId =
            orderRecord.Id;

        paymentRequest.amount =
            totalAmount;

        paymentRequest.paymentMethod =
            request.paymentMethod;

        paymentRequest.receipt =
            'UJ-' + String.valueOf(orderRecord.Id);

        PaymentService.PaymentResult paymentResult =
            PaymentService.createPayment(
                paymentRequest
            );

        /*
         * STEP 5:
         * Reserve inventory.
         *
         * Inventory lookup is intentionally handled
         * inside InventoryReservationService.
         *
         * InventoryReservationService runs without sharing
         * so customer checkout does not require direct
         * record-level visibility to Inventory__c.
         */
        List<Id> reservationIds =
            new List<Id>();

        for (OrderItem item : orderItems) {

            InventoryReservationService.ReservationResult
                reservationResult =
                    InventoryReservationService.reserveInventoryForProduct(
                        item.Product2Id,
                        orderRecord.Id,
                        Integer.valueOf(item.Quantity)
                    );

            reservationIds.add(
                reservationResult.reservationId
            );
        }

        /*
         * STEP 6:
         * Return checkout result.
         */
        CheckoutResult result =
            new CheckoutResult();

        result.orderId =
            orderRecord.Id;

        result.paymentId =
            paymentResult.paymentId;

        result.reservationId =
            reservationIds.isEmpty()
                ? null
                : reservationIds[0];

        result.gatewayOrderId =
            paymentResult.gatewayOrderId;

        result.status =
            'READY_FOR_PAYMENT';

        result.message =
            'Payment order created and inventory reserved successfully.';

        return result;
    }
}