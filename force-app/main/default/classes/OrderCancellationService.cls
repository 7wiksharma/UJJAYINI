public with sharing class OrderCancellationService {

    public static void cancelOrder(
        Id orderId,
        String cancellationReason
    ) {
        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        if (String.isBlank(cancellationReason)) {
            throw new IllegalArgumentException(
                'Cancellation reason is required.'
            );
        }

        Order orderRecord = [
            SELECT Id,
                   Status,
                   Is_Cancelled__c,
                   Cancellation_Reason__c,
                   Cancelled_At__c
            FROM Order
            WHERE Id = :orderId
            FOR UPDATE
        ];

        if (orderRecord.Status != 'Activated') {
            throw new IllegalArgumentException(
                'Only Activated orders can be cancelled.'
            );
        }

        if (orderRecord.Is_Cancelled__c == true) {
            throw new IllegalArgumentException(
                'Order is already cancelled.'
            );
        }

        ReservationReleaseService.releaseReservationsForOrder(
            orderId
        );

        orderRecord.Is_Cancelled__c = true;
        orderRecord.Cancellation_Reason__c = cancellationReason;
        orderRecord.Cancelled_At__c = System.now();

        update orderRecord;
    }
}