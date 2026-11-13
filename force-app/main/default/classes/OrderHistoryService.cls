public without sharing class OrderHistoryService {

    public class OrderResult {

        @AuraEnabled
        public Id orderId;

        @AuraEnabled
        public String orderNumber;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public Date effectiveDate;

        @AuraEnabled
        public Decimal totalAmount;

        @AuraEnabled
        public Integer itemCount;
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

        List<Order> orders = [
            SELECT Id,
                   OrderNumber,
                   Status,
                   EffectiveDate,
                   TotalAmount,
                   (
                       SELECT Id
                       FROM OrderItems
                   )
            FROM Order
            WHERE AccountId = :currentUser.Contact.AccountId
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

            result.effectiveDate =
                orderRecord.EffectiveDate;

            result.totalAmount =
                orderRecord.TotalAmount;

            result.itemCount =
                orderRecord.OrderItems == null
                    ? 0
                    : orderRecord.OrderItems.size();

            results.add(result);
        }

        return results;
    }
}