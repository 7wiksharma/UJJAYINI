@IsTest
private class ReservationReleaseServiceTest {

    @IsTest
    static void testReleasePendingReservation() {

        Account account = new Account(
            Name = 'UJJAYINI Test Account'
        );
        insert account;

        Product2 product = new Product2(
            Name = 'Test UJJAYINI Watch',
            IsActive = true
        );
        insert product;

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 10,
            Reserved__c = 2,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        Order order = new Order(
            AccountId = account.Id,
            Name = 'Test Cancellation Order',
            Status = 'Draft',
            EffectiveDate = Date.today()
        );
        insert order;

        Reservation__c reservation = new Reservation__c(
            Inventory__c = inventory.Id,
            Order__c = order.Id,
            Reserved_Quantity__c = 2,
            Reservation_Status__c = 'Pending',
            Reservation_Created_At__c = System.now(),
            Reservation_Expires_At__c = System.now().addMinutes(15)
        );
        insert reservation;

        Test.startTest();

        Integer releasedCount =
            ReservationReleaseService.releaseReservationsForOrder(
                order.Id
            );

        Test.stopTest();

        System.assertEquals(
            1,
            releasedCount,
            'Exactly one reservation should be released.'
        );

        Reservation__c updatedReservation = [
            SELECT Id,
                   Reservation_Status__c,
                   Reserved_Quantity__c
            FROM Reservation__c
            WHERE Id = :reservation.Id
        ];

        System.assertEquals(
            'Cancelled',
            updatedReservation.Reservation_Status__c,
            'Pending reservation should become Cancelled.'
        );

        Inventory__c updatedInventory = [
            SELECT Id,
                   Reserved__c,
                   On_Hand__c,
                   Available__c
            FROM Inventory__c
            WHERE Id = :inventory.Id
        ];

        System.assertEquals(
            0,
            Integer.valueOf(updatedInventory.Reserved__c),
            'Reserved inventory should be released.'
        );
    }


    @IsTest
    static void testDoesNotReleaseAlreadyCancelledReservation() {

        Account account = new Account(
            Name = 'UJJAYINI Test Account 2'
        );
        insert account;

        Product2 product = new Product2(
            Name = 'Test UJJAYINI Watch 2',
            IsActive = true
        );
        insert product;

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 10,
            Reserved__c = 2,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        Order order = new Order(
            AccountId = account.Id,
            Name = 'Test Already Cancelled Order',
            Status = 'Draft',
            EffectiveDate = Date.today()
        );
        insert order;

        Reservation__c reservation = new Reservation__c(
            Inventory__c = inventory.Id,
            Order__c = order.Id,
            Reserved_Quantity__c = 2,
            Reservation_Status__c = 'Cancelled',
            Reservation_Created_At__c = System.now()
        );
        insert reservation;

        Test.startTest();

        Integer releasedCount =
            ReservationReleaseService.releaseReservationsForOrder(
                order.Id
            );

        Test.stopTest();

        System.assertEquals(
            0,
            releasedCount,
            'Already cancelled reservations must not be released again.'
        );

        Inventory__c unchangedInventory = [
            SELECT Reserved__c
            FROM Inventory__c
            WHERE Id = :inventory.Id
        ];

        System.assertEquals(
            2,
            Integer.valueOf(unchangedInventory.Reserved__c),
            'Inventory reservation must remain unchanged.'
        );
    }
}