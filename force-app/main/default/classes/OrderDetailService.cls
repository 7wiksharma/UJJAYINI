public without sharing class OrderDetailService {

    public class OrderItemResult {

        @AuraEnabled
        public Id orderItemId;

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public Decimal quantity;

        @AuraEnabled
        public Decimal unitPrice;

        @AuraEnabled
        public Decimal totalPrice;
    }

    public class OrderDetailResult {

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
        public List<OrderItemResult> items =
            new List<OrderItemResult>();
    }

    public static OrderDetailResult getOrderDetails(
        Id orderId
    ) {

        if (orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

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
            throw new IllegalArgumentException(
                'The current user is not associated with a customer Account.'
            );
        }

        Order orderRecord = [
            SELECT Id,
                   OrderNumber,
                   Status,
                   EffectiveDate,
                   TotalAmount,
                   AccountId
            FROM Order
            WHERE Id = :orderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (
            orderRecord.AccountId !=
            currentUser.Contact.AccountId
        ) {
            throw new IllegalArgumentException(
                'You are not authorized to view this Order.'
            );
        }

        List<OrderItem> orderItems = [
            SELECT Id,
                   Product2Id,
                   Product2.Name,
                   Quantity,
                   UnitPrice,
                   TotalPrice
            FROM OrderItem
            WHERE OrderId = :orderRecord.Id
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];

        OrderDetailResult result =
            new OrderDetailResult();

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

        for (OrderItem item : orderItems) {

            OrderItemResult itemResult =
                new OrderItemResult();

            itemResult.orderItemId =
                item.Id;

            itemResult.productId =
                item.Product2Id;

            itemResult.productName =
                item.Product2 != null
                    ? item.Product2.Name
                    : 'UJJAYINI Watch';

            itemResult.quantity =
                item.Quantity;

            itemResult.unitPrice =
                item.UnitPrice;

            itemResult.totalPrice =
                item.TotalPrice;

            result.items.add(itemResult);
        }

        return result;
    }
}