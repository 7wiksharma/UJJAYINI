public without sharing class InventoryReservationService {

    private static final Integer DEFAULT_HOLD_MINUTES = 15;

    public class ReservationRequest {
        public Id inventoryId;
        public Id orderId;
        public Integer quantity;
        public Integer holdMinutes;
    }

    public class ReservationResult {
        public Id reservationId;
        public Integer reservedQuantity;
        public Integer availableQuantity;
    }

    public class ConfirmationResult {
        public String status;
        public Integer confirmedReservations = 0;
        public Integer deductedUnits = 0;
    }


    // =========================================================
    // RESERVE (single inventory record)
    // =========================================================

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

        Integer holdMinutes =
            (request.holdMinutes == null || request.holdMinutes <= 0)
                ? DEFAULT_HOLD_MINUTES
                : request.holdMinutes;

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
            Reservation_Expires_At__c =
                reservationCreatedAt.addMinutes(holdMinutes)
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


    // =========================================================
    // RESERVE BY PRODUCT
    // =========================================================

    public static ReservationResult reserveInventoryForProduct(
        Id productId,
        Id orderId,
        Integer quantity
    ) {

        return reserveInventoryForProduct(
            productId,
            orderId,
            quantity,
            DEFAULT_HOLD_MINUTES
        );
    }


    public static ReservationResult reserveInventoryForProduct(
        Id productId,
        Id orderId,
        Integer quantity,
        Integer holdMinutes
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

        request.holdMinutes =
            holdMinutes;

        return reserveInventory(request);
    }


    // =========================================================
    // AVAILABILITY CHECK (read-only, safe before a callout)
    //
    // The order's own earlier Pending holds are added back so a
    // customer retrying payment is not blocked by their own hold.
    // =========================================================

    public static void assertOrderAvailability(Id orderId) {

        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        List<OrderItem> items = [
            SELECT Product2Id,
                   Product2.Name,
                   Quantity
            FROM OrderItem
            WHERE OrderId = :orderId
        ];

        Set<Id> productIds = new Set<Id>();

        for (OrderItem item : items) {
            if (item.Product2Id != null) {
                productIds.add(item.Product2Id);
            }
        }

        Map<Id, Inventory__c> inventoryByProduct =
            new Map<Id, Inventory__c>();

        for (Inventory__c inventory : [
            SELECT Id,
                   Product__c,
                   Available__c
            FROM Inventory__c
            WHERE Product__c IN :productIds
            AND Inventory_Status__c = 'Active'
        ]) {
            if (!inventoryByProduct.containsKey(inventory.Product__c)) {
                inventoryByProduct.put(
                    inventory.Product__c,
                    inventory
                );
            }
        }

        Map<Id, Decimal> ownHolds =
            new Map<Id, Decimal>();

        for (Reservation__c reservation : [
            SELECT Inventory__c,
                   Reserved_Quantity__c
            FROM Reservation__c
            WHERE Order__c = :orderId
            AND Reservation_Status__c = 'Pending'
        ]) {

            Decimal held = ownHolds.get(reservation.Inventory__c);

            if (held == null) {
                held = 0;
            }

            Decimal heldQuantity = reservation.Reserved_Quantity__c;

            if (heldQuantity == null) {
                heldQuantity = 0;
            }

            ownHolds.put(
                reservation.Inventory__c,
                held + heldQuantity
            );
        }

        for (OrderItem item : items) {

            Inventory__c inventory =
                inventoryByProduct.get(item.Product2Id);

            if (inventory == null) {
                throw new IllegalArgumentException(
                    item.Product2.Name +
                    ' is not available for purchase right now.'
                );
            }

            Decimal available = inventory.Available__c;

            if (available == null) {
                available = 0;
            }

            Decimal ownHeld = ownHolds.get(inventory.Id);

            if (ownHeld != null) {
                available = available + ownHeld;
            }

            if (item.Quantity > available) {

                Decimal remaining = available;

                if (remaining < 0) {
                    remaining = 0;
                }

                if (remaining == 0) {
                    throw new IllegalArgumentException(
                        item.Product2.Name +
                        ' is currently unavailable.'
                    );
                }

                throw new IllegalArgumentException(
                    'Only ' +
                    String.valueOf(Integer.valueOf(remaining)) +
                    ' unit(s) of ' +
                    item.Product2.Name +
                    ' remain. Please reduce the quantity in your cart.'
                );
            }
        }
    }


    // =========================================================
    // HOLD STOCK FOR A WHOLE ORDER
    //
    // Releases any earlier Pending hold of the same order
    // (a new payment attempt supersedes the old one), then
    // reserves every order item.
    // =========================================================

    public static List<Id> holdInventoryForOrder(
        Id orderId,
        Integer holdMinutes
    ) {

        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        releasePendingReservationsForOrder(
            orderId,
            'Cancelled'
        );

        List<OrderItem> items = [
            SELECT Product2Id,
                   Quantity
            FROM OrderItem
            WHERE OrderId = :orderId
        ];

        List<Id> reservationIds = new List<Id>();

        for (OrderItem item : items) {

            ReservationResult reservationResult =
                reserveInventoryForProduct(
                    item.Product2Id,
                    orderId,
                    Integer.valueOf(item.Quantity),
                    holdMinutes
                );

            reservationIds.add(
                reservationResult.reservationId
            );
        }

        return reservationIds;
    }


    // =========================================================
    // RELEASE PENDING HOLDS OF AN ORDER
    // (runs without sharing so a customer's checkout can use it)
    // =========================================================

    public static Integer releasePendingReservationsForOrder(
        Id orderId,
        String newStatus
    ) {

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
                       Reserved__c
                FROM Inventory__c
                WHERE Id IN :inventoryIds
                FOR UPDATE
            ]) {
                inventoryMap.put(inventory.Id, inventory);
            }
        }

        Decimal zero = 0;

        for (Reservation__c reservation : reservations) {

            Inventory__c inventory =
                inventoryMap.get(reservation.Inventory__c);

            if (inventory != null) {

                Decimal reserved = inventory.Reserved__c;

                if (reserved == null) {
                    reserved = 0;
                }

                Decimal releaseQuantity =
                    reservation.Reserved_Quantity__c;

                if (releaseQuantity == null) {
                    releaseQuantity = 0;
                }

                inventory.Reserved__c =
                    Math.max(zero, reserved - releaseQuantity);
            }

            reservation.Reservation_Status__c = newStatus;
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


      // =========================================================
    // CONFIRM A PAID ORDER (idempotent)
    //
    // 1. Pending holds exist  -> Confirmed, On_Hand and Reserved
    //                            both go down by the quantity.
    // 2. Already Confirmed    -> nothing to do.
    // 3. No hold left (expired before the payment arrived, or a
    //    payment made before this logic existed) -> On_Hand goes
    //    down by the order quantity and a Confirmed Reservation
    //    row is written as the idempotency marker.
    //
    // Products without an active inventory row are skipped.
    //
    // The webhook runs as the Site Guest User, which has no direct
    // access to Reservation__c / Inventory__c, so every query and
    // DML below uses SYSTEM_MODE (same approach as
    // AssetFulfillmentService and RazorpayWebhookService).
    // =========================================================

    public static ConfirmationResult confirmReservationsForOrder(
        Id orderId
    ) {

        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        ConfirmationResult result =
            new ConfirmationResult();

        result.status = 'NOTHING_TO_CONFIRM';

        Savepoint sp = Database.setSavepoint();

        try {

            List<Reservation__c> reservations = [
                SELECT Id,
                       Inventory__c,
                       Reserved_Quantity__c,
                       Reservation_Status__c
                FROM Reservation__c
                WHERE Order__c = :orderId
                WITH SYSTEM_MODE
                FOR UPDATE
            ];

            List<Reservation__c> pendingReservations =
                new List<Reservation__c>();

            Boolean hasConfirmed = false;

            for (Reservation__c reservation : reservations) {

                if (reservation.Reservation_Status__c == 'Pending') {
                    pendingReservations.add(reservation);
                } else if (
                    reservation.Reservation_Status__c == 'Confirmed'
                ) {
                    hasConfirmed = true;
                }
            }

            if (!pendingReservations.isEmpty()) {

                confirmHeldReservations(
                    pendingReservations,
                    result
                );

            } else if (hasConfirmed) {

                result.status = 'ALREADY_CONFIRMED';

            } else {

                deductForOrderItems(
                    orderId,
                    result
                );
            }

            return result;

        } catch (Exception e) {

            Database.rollback(sp);

            throw e;
        }
    }


    private static void confirmHeldReservations(
        List<Reservation__c> pendingReservations,
        ConfirmationResult result
    ) {

        Set<Id> inventoryIds = new Set<Id>();

        for (Reservation__c reservation : pendingReservations) {
            if (reservation.Inventory__c != null) {
                inventoryIds.add(reservation.Inventory__c);
            }
        }

        Map<Id, Inventory__c> inventoryMap =
            new Map<Id, Inventory__c>();

        if (!inventoryIds.isEmpty()) {

            for (Inventory__c inventory : [
                SELECT Id,
                       On_Hand__c,
                       Reserved__c
                FROM Inventory__c
                WHERE Id IN :inventoryIds
                WITH SYSTEM_MODE
                FOR UPDATE
            ]) {
                inventoryMap.put(inventory.Id, inventory);
            }
        }

        Decimal zero = 0;

        for (Reservation__c reservation : pendingReservations) {

            Decimal quantity = reservation.Reserved_Quantity__c;

            if (quantity == null) {
                quantity = 0;
            }

            Inventory__c inventory =
                inventoryMap.get(reservation.Inventory__c);

            if (inventory != null) {

                Decimal onHand = inventory.On_Hand__c;
                Decimal reserved = inventory.Reserved__c;

                if (onHand == null) {
                    onHand = 0;
                }

                if (reserved == null) {
                    reserved = 0;
                }

                inventory.On_Hand__c =
                    Math.max(zero, onHand - quantity);

                inventory.Reserved__c =
                    Math.max(zero, reserved - quantity);
            }

            reservation.Reservation_Status__c = 'Confirmed';

            result.deductedUnits +=
                Integer.valueOf(quantity);
        }

        if (!inventoryMap.isEmpty()) {
            Database.update(
                inventoryMap.values(),
                System.AccessLevel.SYSTEM_MODE
            );
        }

        Database.update(
            pendingReservations,
            System.AccessLevel.SYSTEM_MODE
        );

        result.confirmedReservations =
            pendingReservations.size();

        result.status = 'CONFIRMED';
    }


    private static void deductForOrderItems(
        Id orderId,
        ConfirmationResult result
    ) {

        Order orderRecord = [
            SELECT Id,
                   Is_Cancelled__c
            FROM Order
            WHERE Id = :orderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (orderRecord.Is_Cancelled__c == true) {
            result.status = 'SKIPPED_CANCELLED_ORDER';
            return;
        }

        List<OrderItem> items = [
            SELECT Product2Id,
                   Quantity
            FROM OrderItem
            WHERE OrderId = :orderId
            WITH SYSTEM_MODE
        ];

        Set<Id> productIds = new Set<Id>();

        for (OrderItem item : items) {
            if (item.Product2Id != null) {
                productIds.add(item.Product2Id);
            }
        }

        Map<Id, Inventory__c> inventoryByProduct =
            new Map<Id, Inventory__c>();

        if (!productIds.isEmpty()) {

            for (Inventory__c inventory : [
                SELECT Id,
                       Product__c,
                       On_Hand__c
                FROM Inventory__c
                WHERE Product__c IN :productIds
                AND Inventory_Status__c = 'Active'
                WITH SYSTEM_MODE
                FOR UPDATE
            ]) {
                if (!inventoryByProduct.containsKey(inventory.Product__c)) {
                    inventoryByProduct.put(
                        inventory.Product__c,
                        inventory
                    );
                }
            }
        }

        Decimal zero = 0;

        Map<Id, Inventory__c> inventoriesToUpdate =
            new Map<Id, Inventory__c>();

        List<Reservation__c> confirmedRows =
            new List<Reservation__c>();

        for (OrderItem item : items) {

            Inventory__c inventory =
                inventoryByProduct.get(item.Product2Id);

            Decimal quantity = item.Quantity;

            if (inventory == null || quantity == null || quantity <= 0) {
                continue;
            }

            Decimal onHand = inventory.On_Hand__c;

            if (onHand == null) {
                onHand = 0;
            }

            inventory.On_Hand__c =
                Math.max(zero, onHand - quantity);

            inventoriesToUpdate.put(
                inventory.Id,
                inventory
            );

            confirmedRows.add(
                new Reservation__c(
                    Inventory__c = inventory.Id,
                    Order__c = orderId,
                    Reserved_Quantity__c = quantity,
                    Reservation_Status__c = 'Confirmed',
                    Reservation_Created_At__c = System.now()
                )
            );

            result.deductedUnits +=
                Integer.valueOf(quantity);
        }

        if (confirmedRows.isEmpty()) {
            result.status = 'NO_INVENTORY_TRACKED';
            return;
        }

        Database.update(
            inventoriesToUpdate.values(),
            System.AccessLevel.SYSTEM_MODE
        );

        Database.insert(
            confirmedRows,
            System.AccessLevel.SYSTEM_MODE
        );

        result.confirmedReservations =
            confirmedRows.size();

        result.status = 'CONFIRMED_WITHOUT_HOLD';
    }
}