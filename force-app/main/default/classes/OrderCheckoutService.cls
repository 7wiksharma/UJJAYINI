public with sharing class OrderCheckoutService {

    public class CheckoutRequest {
        public Id orderId;
        public String paymentMethod;
    }

    public class CheckoutResult {
        public Id orderId;
        public Id paymentId;
        public Id reservationId;
        public String gatewayOrderId;
        public String status;
        public String message;
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

        Decimal totalAmount = 0;

        /*
         * Validate Order Items
         * and calculate total.
         */
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
         * STEP 1:
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
         * STEP 2:
         * Load active inventory.
         */
        Set<Id> productIds =
            getProductIds(orderItems);

        List<Inventory__c> inventoryRecords = [
            SELECT Id,
                   Product__c,
                   On_Hand__c,
                   Reserved__c,
                   Available__c,
                   Inventory_Status__c
            FROM Inventory__c
            WHERE Product__c IN :productIds
            AND Inventory_Status__c = 'Active'
        ];

        Map<Id, Inventory__c> inventoryByProduct =
            new Map<Id, Inventory__c>();

        for (Inventory__c inventory : inventoryRecords) {

            inventoryByProduct.put(
                inventory.Product__c,
                inventory
            );
        }

        /*
         * STEP 3:
         * Reserve inventory.
         */
        List<Id> reservationIds =
            new List<Id>();

        for (OrderItem item : orderItems) {

            Inventory__c inventory =
                inventoryByProduct.get(
                    item.Product2Id
                );

            if (inventory == null) {
                throw new IllegalArgumentException(
                    'Active inventory not found for product: ' +
                    item.Product2Id
                );
            }

            InventoryReservationService.ReservationRequest
                reservationRequest =
                    new InventoryReservationService.ReservationRequest();

            reservationRequest.inventoryId =
                inventory.Id;

            reservationRequest.orderId =
                orderRecord.Id;

            reservationRequest.quantity =
                Integer.valueOf(item.Quantity);

            InventoryReservationService.ReservationResult
                reservationResult =
                    InventoryReservationService.reserveInventory(
                        reservationRequest
                    );

            reservationIds.add(
                reservationResult.reservationId
            );
        }

        /*
         * STEP 4:
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


    private static Set<Id> getProductIds(
        List<OrderItem> orderItems
    ) {

        Set<Id> productIds =
            new Set<Id>();

        for (OrderItem item : orderItems) {

            if (item.Product2Id != null) {
                productIds.add(
                    item.Product2Id
                );
            }
        }

        return productIds;
    }
}