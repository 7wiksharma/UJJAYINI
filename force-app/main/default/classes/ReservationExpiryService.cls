public with sharing class ReservationExpiryService {

    public static Integer expirePendingReservations() {

        List<Reservation__c> expiredReservations = [
            SELECT Id,
                   Inventory__c,
                   Reserved_Quantity__c,
                   Reservation_Status__c,
                   Reservation_Expires_At__c
            FROM Reservation__c
            WHERE Reservation_Status__c = 'Pending'
              AND Reservation_Expires_At__c != NULL
              AND Reservation_Expires_At__c <= :System.now()
            FOR UPDATE 
        ];

        if (expiredReservations.isEmpty()) {
            return 0;
        }

        Set<Id> inventoryIds = new Set<Id>();

        for (Reservation__c reservation : expiredReservations) {
            if (reservation.Inventory__c != null) {
                inventoryIds.add(reservation.Inventory__c);
            }
        }

        Map<Id, Inventory__c> inventoryMap = new Map<Id, Inventory__c>();

        if (!inventoryIds.isEmpty()) {
            for (Inventory__c inventory : [
                SELECT Id,
                       Reserved__c,
                       On_Hand__c,
                       Available__c
                FROM Inventory__c
                WHERE Id IN :inventoryIds
                FOR UPDATE
            ]) {
                inventoryMap.put(inventory.Id, inventory);
            }
        }

        for (Reservation__c reservation : expiredReservations) {

            Inventory__c inventory =
                inventoryMap.get(reservation.Inventory__c);

            if (inventory != null) {

                Integer currentReserved =
                    inventory.Reserved__c == null
                        ? 0
                        : Integer.valueOf(inventory.Reserved__c);

                Integer releaseQuantity =
                    reservation.Reserved_Quantity__c == null
                        ? 0
                        : Integer.valueOf(
                            reservation.Reserved_Quantity__c
                        );

                Integer newReserved =
                    currentReserved - releaseQuantity;

                inventory.Reserved__c =
                    Math.max(0, newReserved);
            }

            reservation.Reservation_Status__c = 'Expired';
        }

        if (!inventoryMap.isEmpty()) {
            update inventoryMap.values();
        }

        update expiredReservations;

        return expiredReservations.size();
    }
}