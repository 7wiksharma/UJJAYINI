Reservation__c reservation = [
    SELECT Id, Inventory__c, Reserved_Quantity__c, Reservation_Status__c
    FROM Reservation__c
    WHERE Id = 'a02bm00000fgFELAA2'
    LIMIT 1
];

Inventory__c inventory = [
    SELECT Id, Reserved__c
    FROM Inventory__c
    WHERE Id = :reservation.Inventory__c
    FOR UPDATE
];

Integer reservedQty = inventory.Reserved__c == null
    ? 0
    : Integer.valueOf(inventory.Reserved__c);

Integer releaseQty = reservation.Reserved_Quantity__c == null
    ? 0
    : Integer.valueOf(reservation.Reserved_Quantity__c);

inventory.Reserved__c = Math.max(0, reservedQty - releaseQty);
update inventory;

reservation.Reservation_Status__c = 'Released';
update reservation;

System.debug('TEST RESERVATION RELEASED = ' + reservation.Id);
System.debug('INVENTORY RESERVED NOW = ' + inventory.Reserved__c);
