public without sharing class OrderHistoryService {

    public class OrderResult {

        @AuraEnabled
        public Id orderId;

        @AuraEnabled
        public String orderNumber;

        @AuraEnabled
        public String status;

        // CONFIRMED or CANCELLED
        @AuraEnabled
        public String displayStatus;

        @AuraEnabled
        public Boolean isCancelled;

        @AuraEnabled
        public Date effectiveDate;

        @AuraEnabled
        public Decimal totalAmount;

        @AuraEnabled
        public Integer itemCount;

        @AuraEnabled
        public String firstProductName;

        @AuraEnabled
        public String firstProductImageUrl;
    }

    public static List<OrderResult> getMyOrders() {

        User currentUser = [
            SELECT Id,
                   ContactId,
                   Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (
            currentUser.ContactId == null ||
            currentUser.Contact.AccountId == null
        ) {
            return new List<OrderResult>();
        }

        /*
         * The Draft order is the customer's cart, so it is not
         * shown as an order.
         */
        List<Order> orders = [
            SELECT Id,
                   OrderNumber,
                   Status,
                   EffectiveDate,
                   TotalAmount,
                   Is_Cancelled__c,
                   Fulfillment_Status__c,
                   (
                       SELECT Id,
                              Product2.Name,
                              Product2.Product_Image_URL__c
                       FROM OrderItems
                       ORDER BY CreatedDate ASC
                   )
            FROM Order
            WHERE AccountId = :currentUser.Contact.AccountId
            AND Status != 'Draft'
            WITH SYSTEM_MODE
            ORDER BY EffectiveDate DESC, CreatedDate DESC
        ];

        List<OrderResult> results = new List<OrderResult>();

        for (Order orderRecord : orders) {

            OrderResult result = new OrderResult();

            result.orderId =
                orderRecord.Id;

            result.orderNumber =
                orderRecord.OrderNumber;

            result.status =
                orderRecord.Status;

            result.displayStatus =
                OrderDetailService.displayStatusFor(orderRecord);

            result.isCancelled =
                orderRecord.Is_Cancelled__c == true;

            result.effectiveDate =
                orderRecord.EffectiveDate;

            result.totalAmount =
                orderRecord.TotalAmount;

            List<OrderItem> items =
                orderRecord.OrderItems == null
                    ? new List<OrderItem>()
                    : orderRecord.OrderItems;

            result.itemCount =
                items.size();

            if (!items.isEmpty() && items[0].Product2 != null) {

                result.firstProductName =
                    items[0].Product2.Name;

                result.firstProductImageUrl =
                    items[0].Product2.Product_Image_URL__c;
            }

            results.add(result);
        }

        return results;
    }
}