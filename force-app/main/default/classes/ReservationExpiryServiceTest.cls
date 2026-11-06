@IsTest
private class ReservationExpiryServiceTest {

    @IsTest
    static void expirePendingReservationSuccessfully() {

        Product2 product = new Product2(
            Name = 'Expiry Test Watch',
            IsActive = true
        );
        insert product;

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 5,
            Reserved__c = 2,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        Account account = new Account(
            Name = 'UJJAYINI Expiry Test Account'
        );
        insert account;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert orderRecord;

        Reservation__c reservation = new Reservation__c(
            Inventory__c = inventory.Id,
            Order__c = orderRecord.Id,
            Reserved_Quantity__c = 2,
            Reservation_Status__c = 'Pending',
            Reservation_Created_At__c = System.now().addMinutes(-30),
            Reservation_Expires_At__c = System.now().addMinutes(-10)
        );
        insert reservation;

        Test.startTest();

        Integer expiredCount =
            ReservationExpiryService.expirePendingReservations();

        Test.stopTest();

        Inventory__c updatedInventory = [
            SELECT Reserved__c,
                   Available__c
            FROM Inventory__c
            WHERE Id = :inventory.Id
        ];

        Reservation__c updatedReservation = [
            SELECT Reservation_Status__c,
                   Reserved_Quantity__c
            FROM Reservation__c
            WHERE Id = :reservation.Id
        ];

        System.assertEquals(
            1,
            expiredCount,
            'One expired reservation should be processed.'
        );

        System.assertEquals(
            0,
            updatedInventory.Reserved__c,
            'Reserved inventory should be released.'
        );

        System.assertEquals(
            5,
            updatedInventory.Available__c,
            'All previously reserved stock should become available.'
        );

        System.assertEquals(
            'Expired',
            updatedReservation.Reservation_Status__c,
            'Reservation should be marked as expired.'
        );

        System.assertEquals(
            2,
            updatedReservation.Reserved_Quantity__c,
            'The original reservation quantity should remain unchanged.'
        );
    }


    @IsTest
    static void ignoresActivePendingReservation() {

        Product2 product = new Product2(
            Name = 'Active Reservation Test Watch',
            IsActive = true
        );
        insert product;

        Inventory__c inventory = new Inventory__c(
            Product__c = product.Id,
            On_Hand__c = 5,
            Reserved__c = 2,
            Inventory_Status__c = 'Active'
        );
        insert inventory;

        Account account = new Account(
            Name = 'UJJAYINI Active Reservation Account'
        );
        insert account;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert orderRecord;

        Reservation__c reservation = new Reservation__c(
            Inventory__c = inventory.Id,
            Order__c = orderRecord.Id,
            Reserved_Quantity__c = 2,
            Reservation_Status__c = 'Pending',
            Reservation_Created_At__c = System.now(),
            Reservation_Expires_At__c = System.now().addMinutes(30)
        );
        insert reservation;

        Test.startTest();

        Integer expiredCount =
            ReservationExpiryService.expirePendingReservations();

        Test.stopTest();

        Inventory__c updatedInventory = [
            SELECT Reserved__c,
                   Available__c
            FROM Inventory__c
            WHERE Id = :inventory.Id
        ];

        Reservation__c updatedReservation = [
            SELECT Reservation_Status__c
            FROM Reservation__c
            WHERE Id = :reservation.Id
        ];

        System.assertEquals(
            0,
            expiredCount,
            'Active pending reservations should not be expired.'
        );

        System.assertEquals(
            2,
            updatedInventory.Reserved__c,
            'Reserved inventory should remain unchanged.'
        );

        System.assertEquals(
            3,
            updatedInventory.Available__c,
            'Available inventory should remain unchanged.'
        );

        System.assertEquals(
            'Pending',
            updatedReservation.Reservation_Status__c,
            'Reservation should remain pending.'
        );
    }
}