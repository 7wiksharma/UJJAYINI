public without sharing class OrderDetailService {

    public class OrderItemResult {

        @AuraEnabled
        public Id orderItemId;

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String productImageUrl;

        @AuraEnabled
        public String collectionName;

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

        // CONFIRMED, CANCELLED or IN CART
        @AuraEnabled
        public String displayStatus;

        @AuraEnabled
        public Date effectiveDate;

        @AuraEnabled
        public Decimal totalAmount;

        // Shipping
        @AuraEnabled
        public String recipientName;

        @AuraEnabled
        public String shippingStreet;

        @AuraEnabled
        public String shippingCity;

        @AuraEnabled
        public String shippingState;

        @AuraEnabled
        public String shippingPostalCode;

        @AuraEnabled
        public String shippingCountry;

        // Payment
        @AuraEnabled
        public String paymentStatus;

        @AuraEnabled
        public String paymentReference;

        @AuraEnabled
        public Datetime paidAt;

        @AuraEnabled
        public Datetime refundedAt;

        // Cancellation
        @AuraEnabled
        public Boolean isCancelled;

        @AuraEnabled
        public Datetime cancelledAt;

        @AuraEnabled
        public String cancellationReason;

        @AuraEnabled
        public Boolean canCancel;
        @AuraEnabled
        public String fulfillmentStatus;
        @AuraEnabled
        public List<OrderItemResult> items =
            new List<OrderItemResult>();
    }


  public static String displayStatusFor(Order orderRecord) {

        if (orderRecord.Is_Cancelled__c == true) {
            return 'CANCELLED';
        }

        if (orderRecord.Status == 'Draft') {
            return 'IN CART';
        }

        return String.isBlank(orderRecord.Fulfillment_Status__c)
            ? 'PROCESSING'
            : orderRecord.Fulfillment_Status__c.toUpperCase();
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

        List<Order> orders = [
            SELECT Id,
                   OrderNumber,
                   Status,
                   EffectiveDate,
                   ActivatedDate,
                   TotalAmount,
                   AccountId,
                   Is_Cancelled__c,
                   Cancelled_At__c,
                   Cancellation_Reason__c,
                   Fulfillment_Status__c,
                   ShipToContact.Name,
                   ShippingStreet,
                   ShippingCity,
                   ShippingState,
                   ShippingPostalCode,
                   ShippingCountry
                   
            FROM Order
            WHERE Id = :orderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (
            orders.isEmpty() ||
            orders[0].AccountId != currentUser.Contact.AccountId
        ) {
            throw new IllegalArgumentException(
                'You are not authorized to view this Order.'
            );
        }

        Order orderRecord = orders[0];

        List<OrderItem> orderItems = [
            SELECT Id,
                   Product2Id,
                   Product2.Name,
                   Product2.Product_Image_URL__c,
                   Product2.Collection__r.Name,
                   Quantity,
                   UnitPrice,
                   TotalPrice
            FROM OrderItem
            WHERE OrderId = :orderRecord.Id
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];

        List<Payment__c> payments = [
            SELECT Id,
                   Name,
                   Payment_Status__c,
                   Paid_At__c,
                   Refunded_At__c
            FROM Payment__c
            WHERE Order__c = :orderRecord.Id
            WITH SYSTEM_MODE
            ORDER BY Paid_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];

        OrderDetailResult result =
            new OrderDetailResult();

        result.orderId =
            orderRecord.Id;

        result.orderNumber =
            orderRecord.OrderNumber;

        result.status =
            orderRecord.Status;

        result.displayStatus =
            displayStatusFor(orderRecord);
        result.fulfillmentStatus =
            String.isBlank(orderRecord.Fulfillment_Status__c)
                ? 'Processing'
                : orderRecord.Fulfillment_Status__c;
        result.effectiveDate =
            orderRecord.EffectiveDate;

        result.totalAmount =
            orderRecord.TotalAmount;

        result.recipientName =
            orderRecord.ShipToContact != null
                ? orderRecord.ShipToContact.Name
                : null;

        result.shippingStreet =
            orderRecord.ShippingStreet;

        result.shippingCity =
            orderRecord.ShippingCity;

        result.shippingState =
            orderRecord.ShippingState;

        result.shippingPostalCode =
            orderRecord.ShippingPostalCode;

        result.shippingCountry =
            orderRecord.ShippingCountry;

        if (!payments.isEmpty()) {

            result.paymentStatus =
                payments[0].Payment_Status__c;

            result.paymentReference =
                payments[0].Name;

            result.paidAt =
                payments[0].Paid_At__c;

            result.refundedAt =
                payments[0].Refunded_At__c;
        }

        result.isCancelled =
            orderRecord.Is_Cancelled__c == true;

        result.cancelledAt =
            orderRecord.Cancelled_At__c;

        result.cancellationReason =
            orderRecord.Cancellation_Reason__c;

        result.canCancel =
            CustomerOrderCancellationService.isCancellable(
                orderRecord
            );

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

            itemResult.productImageUrl =
                item.Product2 != null
                    ? item.Product2.Product_Image_URL__c
                    : null;

            itemResult.collectionName =
                item.Product2 != null &&
                item.Product2.Collection__r != null
                    ? item.Product2.Collection__r.Name
                    : null;

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