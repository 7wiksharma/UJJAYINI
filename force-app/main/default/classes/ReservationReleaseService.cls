public with sharing class ReservationReleaseService {

    public static Integer releaseReservationsForOrder(Id orderId) {

        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        List<Reservation__c> reservations = [
            SELECT Id,
                   Inventory__c,
                   Reserved_Quantity__c,
                   Reservation_Status__c
            FROM Reservation__c
            WHERE Order__c = :orderId
              AND Reservation_Status__c = 'Pending'
            FOR UPDATE
        ];

        if (reservations.isEmpty()) {
            return 0;
        }

        Set<Id> inventoryIds = new Set<Id>();

        for (Reservation__c reservation : reservations) {
            if (reservation.Inventory__c != null) {
                inventoryIds.add(reservation.Inventory__c);
            }
        }

        Map<Id, Inventory__c> inventoryMap =
            new Map<Id, Inventory__c>();

        if (!inventoryIds.isEmpty()) {

            for (Inventory__c inventory : [
                SELECT Id,
                       Reserved__c,
                       On_Hand__c,
                       Available__c,
                       Inventory_Status__c
                FROM Inventory__c
                WHERE Id IN :inventoryIds
                FOR UPDATE
            ]) {
                inventoryMap.put(inventory.Id, inventory);
            }
        }

        for (Reservation__c reservation : reservations) {

            Inventory__c inventory =
                inventoryMap.get(reservation.Inventory__c);

            if (inventory != null) {

                Integer currentReserved =
                    inventory.Reserved__c == null
                        ? 0
                        : Integer.valueOf(
                            inventory.Reserved__c
                        );

                Integer releaseQuantity =
                    reservation.Reserved_Quantity__c == null
                        ? 0
                        : Integer.valueOf(
                            reservation.Reserved_Quantity__c
                        );

                inventory.Reserved__c =
                    Math.max(
                        0,
                        currentReserved - releaseQuantity
                    );
            }

            reservation.Reservation_Status__c = 'Cancelled';
        }

        if (!inventoryMap.isEmpty()) {
            Database.update(
                inventoryMap.values(),
                System.AccessLevel.SYSTEM_MODE
            );
        }

        update reservations;

        return reservations.size();
    }
}