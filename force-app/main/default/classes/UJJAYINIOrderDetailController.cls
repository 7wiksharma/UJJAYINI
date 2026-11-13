public with sharing class UJJAYINIOrderDetailController {

    @AuraEnabled(cacheable=true)
    public static OrderDetailService.OrderDetailResult getOrderDetails(
        Id orderId
    ) {

        try {

            return OrderDetailService.getOrderDetails(
                orderId
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}