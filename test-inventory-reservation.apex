InventoryReservationService.ReservationResult result =
    InventoryReservationService.reserveInventoryForProduct(
        '01tbm00000UqzcPAAR',
        '801bm00003HCTNuAAP',
        1
    );

System.debug('RESERVATION ID = ' + result.reservationId);
System.debug('RESERVED QTY = ' + result.reservedQuantity);
System.debug('AVAILABLE QTY = ' + result.availableQuantity);
