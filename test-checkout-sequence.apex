Order orderRecord = [
    SELECT Id, Status
    FROM Order
    WHERE Id = '801bm00003HCTNuAAP'
    LIMIT 1
];

List<OrderItem> orderItems = [
    SELECT Id, Product2Id, Quantity, UnitPrice, TotalPrice
    FROM OrderItem
    WHERE OrderId = :orderRecord.Id
];

System.debug('ORDER STATUS = ' + orderRecord.Status);
System.debug('ORDER ITEMS = ' + orderItems.size());

Decimal totalAmount = 0;

for (OrderItem item : orderItems) {
    totalAmount += item.TotalPrice;
}

System.debug('TOTAL = ' + totalAmount);

PaymentService.PaymentRequest paymentRequest =
    new PaymentService.PaymentRequest();

paymentRequest.orderId = orderRecord.Id;
paymentRequest.amount = totalAmount;
paymentRequest.paymentMethod = 'Other';
paymentRequest.receipt = 'UJ-' + String.valueOf(orderRecord.Id);

PaymentService.PaymentResult paymentResult =
    PaymentService.createPayment(paymentRequest);

System.debug('PAYMENT ID = ' + paymentResult.paymentId);
System.debug('GATEWAY ORDER ID = ' + paymentResult.gatewayOrderId);

for (OrderItem item : orderItems) {

    InventoryReservationService.ReservationResult reservationResult =
        InventoryReservationService.reserveInventoryForProduct(
            item.Product2Id,
            orderRecord.Id,
            Integer.valueOf(item.Quantity)
        );

    System.debug(
        'RESERVATION ID = ' +
        reservationResult.reservationId +
        ' | AVAILABLE = ' +
        reservationResult.availableQuantity
    );
}
