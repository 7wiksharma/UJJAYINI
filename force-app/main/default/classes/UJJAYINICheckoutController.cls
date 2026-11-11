public with sharing class UJJAYINICheckoutController {

    @AuraEnabled
    public static OrderCheckoutService.CheckoutResult checkout(
        Id orderId,
        String paymentMethod
    ) {
        if (orderId == null) {
            throw new AuraHandledException(
                'Order Id is required.'
            );
        }

        OrderCheckoutService.CheckoutRequest request =
            new OrderCheckoutService.CheckoutRequest();

        request.orderId = orderId;
        request.paymentMethod = paymentMethod;

        try {
            return OrderCheckoutService.checkout(request);

        } catch (Exception e) {
            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}