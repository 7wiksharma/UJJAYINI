public without sharing class CustomerOrderCancellationService {

    /*
     * Online cancellation is allowed for this many days after the
     * order is activated (paid). Change this to change the policy.
     */
    @TestVisible
    private static final Integer CANCELLATION_WINDOW_DAYS = 7;

        /*
     * Customers can cancel only before the order leaves the house.
     * A blank status is treated as Processing (older orders).
     */
    private static final Set<String> CANCELLABLE_FULFILLMENT_STATUSES =
        new Set<String>{ 'Processing', 'Packed' };


    public static Boolean hasLeftTheHouse(Order orderRecord) {

        String status =
            String.isBlank(orderRecord.Fulfillment_Status__c)
                ? 'Processing'
                : orderRecord.Fulfillment_Status__c;

        return !CANCELLABLE_FULFILLMENT_STATUSES.contains(status);
    }
    /*
     * Used only by tests: lets a test choose the customer Account
     * without creating a real Experience Cloud user.
     */
    @TestVisible
    private static Id testAccountId;


    public class CancellationResult {

        @AuraEnabled public Id orderId;
        @AuraEnabled public Boolean refunded;
        @AuraEnabled public String refundStatus;
        @AuraEnabled public String message;
    }


    // =========================================================
    // RULE (also used by OrderDetailService to show the button)
    // =========================================================

    public static Boolean isCancellable(Order orderRecord) {

        if (
            orderRecord == null ||
            orderRecord.Status != 'Activated' ||
            orderRecord.Is_Cancelled__c == true
        ) {
            return false;
        }
 if (hasLeftTheHouse(orderRecord)) {
            return false;
        }
        Datetime since =
            orderRecord.ActivatedDate;

        if (since == null && orderRecord.EffectiveDate != null) {

            since = Datetime.newInstance(
                orderRecord.EffectiveDate,
                Time.newInstance(0, 0, 0, 0)
            );
        }

        if (since == null) {
            return false;
        }

        return since.addDays(CANCELLATION_WINDOW_DAYS) >= System.now();
    }


    // =========================================================
    // CANCEL MY ORDER
    // =========================================================

    public static CancellationResult cancelMyOrder(Id orderId) {

        if (orderId == null) {
            fail('Order Id is required.');
        }

        Id accountId =
            getCurrentAccountId();

        if (accountId == null) {
            fail('Please sign in to manage your orders.');
        }


        List<Order> orders = [
            SELECT Id,
                   Status,
                   AccountId,
                   Is_Cancelled__c,
                   ActivatedDate,
                   EffectiveDate,
                    Fulfillment_Status__c
            FROM Order
            WHERE Id = :orderId
            AND AccountId = :accountId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            fail('Order not found.');
        }

        Order orderRecord = orders[0];

        if (orderRecord.Is_Cancelled__c == true) {
            fail('This order has already been cancelled.');
        }
    if (hasLeftTheHouse(orderRecord)) {
            fail(
                'This order has already been shipped and can no ' +
                'longer be cancelled. Please contact UJJAYINI Service.'
            );
        }
        if (!isCancellable(orderRecord)) {
            fail(
                'This order can no longer be cancelled online. ' +
                'Please contact UJJAYINI Service.'
            );
        }


        List<Payment__c> payments = [
            SELECT Id,
                   Amount__c,
                   Payment_Status__c,
                   Gateway_Payment_ID__c,
                   Gateway_Refund_ID__c
            FROM Payment__c
            WHERE Order__c = :orderRecord.Id
            AND Payment_Status__c = 'Captured'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Payment__c payment =
            payments.isEmpty()
                ? null
                : payments[0];


        // -----------------------------------------------------
        // 1. REFUND FIRST
        //    The Razorpay callout must happen before any DML.
        //    If it fails, nothing is cancelled.
        // -----------------------------------------------------

        RazorpayGatewayService.CreateRefundResult refund = null;

        if (
            payment != null &&
            String.isBlank(payment.Gateway_Refund_ID__c)
        ) {

            if (String.isBlank(payment.Gateway_Payment_ID__c)) {
                fail(
                    'This payment cannot be refunded online. ' +
                    'Please contact UJJAYINI Service.'
                );
            }

            RazorpayGatewayService.CreateRefundRequest refundRequest =
                new RazorpayGatewayService.CreateRefundRequest();

            refundRequest.razorpayPaymentId =
                payment.Gateway_Payment_ID__c;

            // null amount = full refund
            refundRequest.amount = null;

            refundRequest.receipt =
                'UJ-REFUND-' + String.valueOf(orderRecord.Id);

            refundRequest.notes =
                'Customer cancellation';

            try {

                refund =
                    RazorpayGatewayService.createRefund(
                        refundRequest
                    );

            } catch (Exception e) {

                System.debug(
                    LoggingLevel.ERROR,
                    'UJJAYINI refund failed: ' + e.getMessage()
                );

                fail(
                    'We could not start your refund, so the order ' +
                    'has not been cancelled. Please try again or ' +
                    'contact UJJAYINI Service.'
                );
            }
        }


        // -----------------------------------------------------
        // 2. RECORD THE CANCELLATION
        // -----------------------------------------------------

        Savepoint sp = Database.setSavepoint();

        try {

            Database.update(
                new Order(
                    Id = orderRecord.Id,
                    Is_Cancelled__c = true,
                    Cancellation_Reason__c = 'Customer Request',
                    Cancelled_At__c = System.now()
                ),
                AccessLevel.SYSTEM_MODE
            );

            if (payment != null && refund != null) {

                Database.update(
                    new Payment__c(
                        Id = payment.Id,
                        Gateway_Refund_ID__c = refund.razorpayRefundId,
                        Payment_Status__c = 'Refunded',
                        Refunded_At__c = System.now()
                    ),
                    AccessLevel.SYSTEM_MODE
                );
            }

            // Unpaid holds of this order (if any) go back to stock.
            InventoryReservationService.releasePendingReservationsForOrder(
                orderRecord.Id,
                'Cancelled'
            );

            // Paid (confirmed) stock goes back on the shelf.
            restockConfirmedReservations(orderRecord.Id);

            // The watch leaves the Collector Vault.
            retireOwnership(orderRecord.Id);

        } catch (Exception e) {

            Database.rollback(sp);

            System.debug(
                LoggingLevel.ERROR,
                'UJJAYINI cancellation failed after refund: ' +
                e.getMessage()
            );

            fail(
                refund != null
                    ? 'Your refund has been started, but the ' +
                      'cancellation could not be completed. Please ' +
                      'contact UJJAYINI Service.'
                    : 'The order could not be cancelled. Please ' +
                      'contact UJJAYINI Service.'
            );
        }

 // Cancellation email with the credit note (never throws).
        OrderInvoiceService.sendCancellationEmailSafely(
            orderRecord.Id
        );
        CancellationResult result =
            new CancellationResult();

        result.orderId = orderRecord.Id;
        result.refunded = refund != null;
        result.refundStatus = refund != null ? refund.status : null;

        result.message =
            refund != null
                ? 'Your order has been cancelled. The refund has ' +
                  'been started to your original payment method.'
                : 'Your order has been cancelled.';

        return result;
    }


    // =========================================================
    // HELPERS
    // =========================================================

    private static void restockConfirmedReservations(Id orderId) {

        List<Reservation__c> confirmed = [
            SELECT Id,
                   Inventory__c,
                   Reserved_Quantity__c
            FROM Reservation__c
            WHERE Order__c = :orderId
            AND Reservation_Status__c = 'Confirmed'
            WITH SYSTEM_MODE
            FOR UPDATE
        ];

        if (confirmed.isEmpty()) {
            return;
        }

        Set<Id> inventoryIds = new Set<Id>();

        for (Reservation__c reservation : confirmed) {
            if (reservation.Inventory__c != null) {
                inventoryIds.add(reservation.Inventory__c);
            }
        }

        Map<Id, Inventory__c> inventoryMap =
            new Map<Id, Inventory__c>();

        if (!inventoryIds.isEmpty()) {

            for (Inventory__c inventory : [
                SELECT Id,
                       On_Hand__c
                FROM Inventory__c
                WHERE Id IN :inventoryIds
                WITH SYSTEM_MODE
                FOR UPDATE
            ]) {
                inventoryMap.put(inventory.Id, inventory);
            }
        }

        for (Reservation__c reservation : confirmed) {

            Inventory__c inventory =
                inventoryMap.get(reservation.Inventory__c);

            Decimal quantity =
                reservation.Reserved_Quantity__c == null
                    ? 0
                    : reservation.Reserved_Quantity__c;

            if (inventory != null) {

                Decimal onHand =
                    inventory.On_Hand__c == null
                        ? 0
                        : inventory.On_Hand__c;

                inventory.On_Hand__c = onHand + quantity;
            }

            reservation.Reservation_Status__c = 'Released';
        }

        if (!inventoryMap.isEmpty()) {
            Database.update(
                inventoryMap.values(),
                AccessLevel.SYSTEM_MODE
            );
        }

        Database.update(
            confirmed,
            AccessLevel.SYSTEM_MODE
        );
    }


    /*
     * Hides the cancelled watch from the Collector Vault and voids
     * its warranty. allOrNone = false: a picklist difference in
     * this org must never block the cancellation.
     */
    private static void retireOwnership(Id orderId) {

        String fulfillmentMarker =
            'UJJAYINI-' + String.valueOf(orderId);

        List<Asset> assets = [
            SELECT Id
            FROM Asset
            WHERE SerialNumber = :fulfillmentMarker
            WITH SYSTEM_MODE
        ];

        if (assets.isEmpty()) {
            return;
        }

        Set<Id> assetIds = new Set<Id>();

        for (Asset asset : assets) {
            asset.Status = 'Obsolete';
            assetIds.add(asset.Id);
        }

        logFailures(
            Database.update(
                assets,
                false,
                AccessLevel.SYSTEM_MODE
            )
        );

        List<Warranty__c> warranties = [
            SELECT Id
            FROM Warranty__c
            WHERE Asset__c IN :assetIds
            WITH SYSTEM_MODE
        ];

        for (Warranty__c warranty : warranties) {
            warranty.Warranty_Status__c = 'Voided';
        }

        if (!warranties.isEmpty()) {
            logFailures(
                Database.update(
                    warranties,
                    false,
                    AccessLevel.SYSTEM_MODE
                )
            );
        }
    }


    private static void logFailures(
        List<Database.SaveResult> results
    ) {

        for (Database.SaveResult saveResult : results) {

            if (!saveResult.isSuccess()) {

                System.debug(
                    LoggingLevel.ERROR,
                    'UJJAYINI cancellation follow-up failed: ' +
                    saveResult.getErrors()[0].getMessage()
                );
            }
        }
    }


    private static Id getCurrentAccountId() {

        if (
            Test.isRunningTest() &&
            testAccountId != null
        ) {
            return testAccountId;
        }

        User currentUser = [
            SELECT Id,
                   ContactId,
                   Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return currentUser.ContactId == null
            ? null
            : currentUser.Contact.AccountId;
    }


    private static void fail(String message) {

        AuraHandledException error =
            new AuraHandledException(message);

        error.setMessage(message);

        throw error;
    }
}