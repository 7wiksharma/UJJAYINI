public without sharing class InventoryReservationService {

    public class ReservationRequest {
        public Id inventoryId;
        public Id orderId;
        public Integer quantity;
    }

    public class ReservationResult {
        public Id reservationId;
        public Integer reservedQuantity;
        public Integer availableQuantity;
    }

    public static ReservationResult reserveInventory(ReservationRequest request) {

        if (request == null) {
            throw new IllegalArgumentException(
                'Reservation request is required.'
            );
        }

        if (request.inventoryId == null) {
            throw new IllegalArgumentException(
                'Inventory Id is required.'
            );
        }

        if (request.orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        if (request.quantity == null || request.quantity <= 0) {
            throw new IllegalArgumentException(
                'Reservation quantity must be greater than zero.'
            );
        }

        Inventory__c inventory = [
            SELECT Id,
                   On_Hand__c,
                   Reserved__c,
                   Available__c,
                   Inventory_Status__c
            FROM Inventory__c
            WHERE Id = :request.inventoryId
            WITH SYSTEM_MODE
            FOR UPDATE
        ];

        if (inventory.Inventory_Status__c != 'Active') {
            throw new IllegalArgumentException(
                'Inventory is not active for reservation.'
            );
        }

        Integer availableQuantity =
            Integer.valueOf(inventory.Available__c);

        if (request.quantity > availableQuantity) {
            throw new IllegalArgumentException(
                'Insufficient inventory. Available quantity: ' +
                availableQuantity
            );
        }

        Integer currentReserved =
            inventory.Reserved__c == null
                ? 0
                : Integer.valueOf(inventory.Reserved__c);

        inventory.Reserved__c =
            currentReserved + request.quantity;

        Database.update(
       inventory,
    System.AccessLevel.SYSTEM_MODE
);

       Datetime reservationCreatedAt = System.now();

Reservation__c reservation = new Reservation__c(
    Inventory__c = inventory.Id,
    Order__c = request.orderId,
    Reserved_Quantity__c = request.quantity,
    Reservation_Status__c = 'Pending',
    Reservation_Created_At__c = reservationCreatedAt,
    Reservation_Expires_At__c = reservationCreatedAt.addMinutes(15)
);
        insert reservation;

        ReservationResult result = new ReservationResult();

        result.reservationId =
            reservation.Id;

        result.reservedQuantity =
            request.quantity;

        result.availableQuantity =
            availableQuantity - request.quantity;

        return result;
    }

    public static ReservationResult reserveInventoryForProduct(
        Id productId,
        Id orderId,
        Integer quantity
    ) {

        if (productId == null) {
            throw new IllegalArgumentException(
                'Product Id is required.'
            );
        }

        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        if (quantity == null || quantity <= 0) {
            throw new IllegalArgumentException(
                'Reservation quantity must be greater than zero.'
            );
        }

        List<Inventory__c> inventoryRecords = [
    SELECT Id,
           Product__c,
           On_Hand__c,
           Reserved__c,
           Available__c,
           Inventory_Status__c
    FROM Inventory__c
    WHERE Product__c = :productId
    AND Inventory_Status__c = 'Active'
    LIMIT 1
];

        if (inventoryRecords.isEmpty()) {
            throw new IllegalArgumentException(
                'Active inventory not found for product: ' +
                productId
            );
        }

        ReservationRequest request =
            new ReservationRequest();

        request.inventoryId =
            inventoryRecords[0].Id;

        request.orderId =
            orderId;

        request.quantity =
            quantity;

        return reserveInventory(request);
    }
}