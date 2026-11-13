public with sharing class UJJAYINIOrderHistoryController {

    @AuraEnabled(cacheable=true)
    public static List<OrderHistoryService.OrderResult> getMyOrders() {

        try {

            return OrderHistoryService.getMyOrders();

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}