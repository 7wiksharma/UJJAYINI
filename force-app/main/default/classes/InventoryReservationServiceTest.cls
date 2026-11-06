@IsTest
private class InventoryReservationServiceTest {

    @IsTest
    static void reserveInventorySuccessfully() {

        Product2 product = new Product2(
            Name = 'Test Watch',
            IsActive = true
        );
        insert product;

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 5,
            Reserved__c = 0,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        Order orderRecord = new Order(
            AccountId = createAccount().Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert orderRecord;

        InventoryReservationService.ReservationRequest request =
            new InventoryReservationService.ReservationRequest();

        request.inventoryId = inventory.Id;
        request.orderId = orderRecord.Id;
        request.quantity = 2;

        Test.startTest();

        InventoryReservationService.ReservationResult result =
            InventoryReservationService.reserveInventory(request);

        Test.stopTest();

        Inventory__c updatedInventory = [
            SELECT Reserved__c, Available__c
            FROM Inventory__c
            WHERE Id = :inventory.Id
        ];

        Reservation__c reservation = [
            SELECT Inventory__c,
                   Order__c,
                   Reserved_Quantity__c,
                   Reservation_Status__c
            FROM Reservation__c
            WHERE Id = :result.reservationId
        ];

        System.assertEquals(2, result.reservedQuantity);
        System.assertEquals(3, result.availableQuantity);

        System.assertEquals(2, updatedInventory.Reserved__c);
        System.assertEquals(3, updatedInventory.Available__c);

        System.assertEquals(inventory.Id, reservation.Inventory__c);
        System.assertEquals(orderRecord.Id, reservation.Order__c);
        System.assertEquals(2, reservation.Reserved_Quantity__c);
        System.assertEquals('Pending', reservation.Reservation_Status__c);
    }

    @IsTest
    static void reservationFailsWhenQuantityExceedsAvailable() {

        Product2 product = new Product2(
            Name = 'Limited Watch',
            IsActive = true
        );
        insert product;

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 1,
            Reserved__c = 0,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        Account account = createAccount();

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert orderRecord;

        InventoryReservationService.ReservationRequest request =
            new InventoryReservationService.ReservationRequest();

        request.inventoryId = inventory.Id;
        request.orderId = orderRecord.Id;
        request.quantity = 2;

        Test.startTest();

        try {
            InventoryReservationService.reserveInventory(request);
            System.assert(false, 'Expected reservation to fail.');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('Insufficient inventory')
            );
        }

        Test.stopTest();
    }

    private static Account createAccount() {
        Account account = new Account(
            Name = 'UJJAYINI Test Account'
        );
        insert account;
        return account;
    }
}