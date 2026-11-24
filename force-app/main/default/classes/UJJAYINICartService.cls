public with sharing class UJJAYINICartService {

    @TestVisible
    private static Id testContactId;

    @TestVisible
    private static Id testStandardPricebookId;


    // =========================================================
    // CART ITEM RESULT
    // =========================================================

    public class CartItemResult {

        @AuraEnabled
        public Id orderItemId;

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String productCode;

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

        // How many pieces this customer may have in the cart in
        // total (stock left + pieces this cart already holds).
        // The cart page disables "+" when quantity reaches it.
        @AuraEnabled
        public Decimal availableStock;
    }


    // =========================================================
    // CART RESULT
    // =========================================================

    public class CartResult {

        @AuraEnabled
        public Id orderId;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public Decimal totalAmount;

        @AuraEnabled
        public List<CartItemResult> items =
            new List<CartItemResult>();
    }


    // =========================================================
    // GET CURRENT CONTACT ID
    // =========================================================

    private static Id getCurrentContactId() {

        if (Test.isRunningTest() &&
            testContactId != null) {

            return testContactId;
        }

        User currentUser = [
            SELECT Id,
                   ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        return currentUser.ContactId;
    }


    // =========================================================
    // GET STANDARD PRICEBOOK ID
    // =========================================================

    private static Id getStandardPricebookId() {

        if (Test.isRunningTest() &&
            testStandardPricebookId != null) {

            return testStandardPricebookId;
        }

        Pricebook2 standardPricebook = [
            SELECT Id,
                   IsActive
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];

        if (!standardPricebook.IsActive) {

            throw friendlyError(
                'Standard Pricebook is not active.'
            );
        }

        return standardPricebook.Id;
    }


    // =========================================================
    // ADD TO CART
    // =========================================================

    @AuraEnabled
    public static CartResult addToCart(
        Id productId,
        Integer quantity
    ) {

        if (productId == null) {

            throw friendlyError(
                'Product Id is required.'
            );
        }

        if (quantity == null || quantity <= 0) {

            throw friendlyError(
                'Quantity must be greater than zero.'
            );
        }


        // -----------------------------------------------------
        // GET CUSTOMER CONTACT
        // -----------------------------------------------------

        Id contactId =
            getCurrentContactId();

        if (contactId == null) {

            throw friendlyError(
                'Your user account is not linked to a Contact.'
            );
        }


        // -----------------------------------------------------
        // GET CUSTOMER ACCOUNT
        // -----------------------------------------------------

        Contact customer = [
            SELECT Id,
                   AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (customer.AccountId == null) {

            throw friendlyError(
                'Your Contact is not linked to an Account.'
            );
        }


        // -----------------------------------------------------
        // GET PRODUCT
        // -----------------------------------------------------

        Product2 product = [
            SELECT Id,
                   Name,
                   IsActive
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];

        if (!product.IsActive) {

            throw friendlyError(
                'This product is not currently available.'
            );
        }


        // -----------------------------------------------------
        // GET STANDARD PRICEBOOK
        // -----------------------------------------------------

        Id standardPricebookId =
            getStandardPricebookId();


        // -----------------------------------------------------
        // GET PRODUCT PRICE
        // -----------------------------------------------------

        PricebookEntry pricebookEntry = [
            SELECT Id,
                   Product2Id,
                   UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId
            AND Product2Id = :productId
            AND IsActive = true
            LIMIT 1
        ];


        // -----------------------------------------------------
        // FIND EXISTING DRAFT ORDER
        // -----------------------------------------------------

        List<Order> draftOrders = [
            SELECT Id,
                   Status,
                   AccountId,
                   Pricebook2Id
            FROM Order
            WHERE AccountId = :customer.AccountId
            AND Status = 'Draft'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Order cartOrder;


        // -----------------------------------------------------
        // CREATE DRAFT ORDER
        // -----------------------------------------------------

        if (draftOrders.isEmpty()) {

            cartOrder = new Order(
                AccountId = customer.AccountId,
                EffectiveDate = Date.today(),
                Status = 'Draft',
                Pricebook2Id = standardPricebookId
            );

            insert cartOrder;

        } else {

            cartOrder = draftOrders[0];
        }


        // -----------------------------------------------------
        // FIND EXISTING CART ITEM
        //
        // IMPORTANT:
        // Only query fields required for update.
        // TotalPrice is calculated/read-only.
        // -----------------------------------------------------

        List<OrderItem> existingItems = [
            SELECT Id,
                   Quantity
            FROM OrderItem
            WHERE OrderId = :cartOrder.Id
            AND Product2Id = :productId
            LIMIT 1
        ];


        // -----------------------------------------------------
        // STOCK CHECK
        //
        // The cart can never hold more pieces than are really
        // available. (Earlier, stock was only checked at
        // "Proceed to Payment", so any quantity could be added.)
        // -----------------------------------------------------

        Decimal alreadyInCart = existingItems.isEmpty()
            ? 0
            : existingItems[0].Quantity;

        Decimal available =
            availableFor(productId, cartOrder.Id);

        if (available <= 0) {
            throw friendlyError(
                'This timepiece is currently sold out.'
            );
        }

        if (alreadyInCart + quantity > available) {
            throw friendlyError(
                alreadyInCart >= available
                    ? 'You already have every available piece of this timepiece in your cart.'
                    : 'Only ' + available.intValue() + ' piece(s) of this timepiece are available.'
            );
        }


        // -----------------------------------------------------
        // UPDATE EXISTING ITEM
        // -----------------------------------------------------

        if (!existingItems.isEmpty()) {

            OrderItem existingItem =
                existingItems[0];

            existingItem.Quantity =
                existingItem.Quantity + quantity;

            update existingItem;

        }

        // -----------------------------------------------------
        // CREATE NEW ITEM
        // -----------------------------------------------------

        else {

            OrderItem newItem = new OrderItem(
                OrderId = cartOrder.Id,
                PricebookEntryId = pricebookEntry.Id,
                Quantity = quantity,
                UnitPrice = pricebookEntry.UnitPrice
            );

            insert newItem;
        }


        // -----------------------------------------------------
        // RETURN UPDATED CART
        // -----------------------------------------------------

        return getCart(cartOrder.Id);
    }


    // =========================================================
    // FRIENDLY ERROR
    //
    // An AuraHandledException made with only a constructor
    // message returns "Script-thrown exception" from
    // getMessage(). The controller re-throws using getMessage(),
    // so the customer saw "Script-thrown exception".
    // setMessage() makes getMessage() return the real text.
    // =========================================================

    private static AuraHandledException friendlyError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }


    // =========================================================
    // AVAILABLE STOCK FOR SEVERAL WATCHES (one query each, bulk)
    // =========================================================

    private static Map<Id, Decimal> availableByProduct(Set<Id> productIds, Id cartOrderId) {

        Map<Id, Decimal> result = new Map<Id, Decimal>();

        for (Id productId : productIds) {
            result.put(productId, 0);
        }

        for (Inventory__c inventory : [
            SELECT Product__c, Available__c
            FROM Inventory__c
            WHERE Product__c IN :productIds
            AND Inventory_Status__c = 'Active'
            WITH SYSTEM_MODE
        ]) {
            result.put(
                inventory.Product__c,
                result.get(inventory.Product__c)
                    + (inventory.Available__c == null ? 0 : inventory.Available__c)
            );
        }

        for (Reservation__c hold : [
            SELECT Inventory__r.Product__c, Reserved_Quantity__c
            FROM Reservation__c
            WHERE Order__c = :cartOrderId
            AND Reservation_Status__c = 'Pending'
            AND Inventory__r.Product__c IN :productIds
            WITH SYSTEM_MODE
        ]) {
            Id productId = hold.Inventory__r.Product__c;
            result.put(
                productId,
                result.get(productId)
                    + (hold.Reserved_Quantity__c == null ? 0 : hold.Reserved_Quantity__c)
            );
        }

        return result;
    }


    // =========================================================
    // AVAILABLE STOCK FOR ONE WATCH
    //
    // Available__c = On Hand - Reserved. Pieces that THIS cart
    // already holds (after "Proceed to Payment") still belong to
    // this customer, so they are added back.
    // =========================================================

    private static Decimal availableFor(Id productId, Id cartOrderId) {

        Decimal available = 0;

        for (Inventory__c inventory : [
            SELECT Available__c
            FROM Inventory__c
            WHERE Product__c = :productId
            AND Inventory_Status__c = 'Active'
            WITH SYSTEM_MODE
        ]) {
            available += inventory.Available__c == null ? 0 : inventory.Available__c;
        }

        for (Reservation__c hold : [
            SELECT Reserved_Quantity__c
            FROM Reservation__c
            WHERE Order__c = :cartOrderId
            AND Reservation_Status__c = 'Pending'
            AND Inventory__r.Product__c = :productId
            WITH SYSTEM_MODE
        ]) {
            available += hold.Reserved_Quantity__c == null ? 0 : hold.Reserved_Quantity__c;
        }

        return available;
    }


    // =========================================================
    // GET CURRENT CART
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static CartResult getCurrentCart() {

        Id contactId =
            getCurrentContactId();

        if (contactId == null) {

            throw friendlyError(
                'Your user account is not linked to a Contact.'
            );
        }


        // -----------------------------------------------------
        // GET CUSTOMER ACCOUNT
        // -----------------------------------------------------

        Contact customer = [
            SELECT Id,
                   AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (customer.AccountId == null) {

            throw friendlyError(
                'Your Contact is not linked to an Account.'
            );
        }


        // -----------------------------------------------------
        // FIND CURRENT DRAFT ORDER
        // -----------------------------------------------------

        List<Order> draftOrders = [
            SELECT Id
            FROM Order
            WHERE AccountId = :customer.AccountId
            AND Status = 'Draft'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];


        // -----------------------------------------------------
        // EMPTY CART
        // -----------------------------------------------------

        if (draftOrders.isEmpty()) {

            CartResult emptyCart =
                new CartResult();

            emptyCart.status = 'EMPTY';
            emptyCart.totalAmount = 0;

            return emptyCart;
        }


        // -----------------------------------------------------
        // RETURN CART
        // -----------------------------------------------------

        return getCart(draftOrders[0].Id);
    }


    // =========================================================
    // GET CURRENT DRAFT ORDER
    // =========================================================

    private static Order getCart() {

        Id contactId =
            getCurrentContactId();

        if (contactId == null) {

            throw new IllegalArgumentException(
                'Your user account is not linked to a Contact.'
            );
        }


        Contact customer = [
            SELECT Id,
                   AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (customer.AccountId == null) {

            throw new IllegalArgumentException(
                'Your Contact is not linked to an Account.'
            );
        }


        List<Order> draftOrders = [
            SELECT Id,
                   Status,
                   AccountId,
                   Pricebook2Id
            FROM Order
            WHERE AccountId = :customer.AccountId
            AND Status = 'Draft'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];


        if (draftOrders.isEmpty()) {

            return null;
        }


        return draftOrders[0];
    }


    // =========================================================
    // GET CART BY ORDER ID
    // =========================================================

    private static CartResult getCart(Id orderId) {

        Order orderRecord = [
            SELECT Id,
                   Status
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];


        // -----------------------------------------------------
        // GET CART ITEMS
        // -----------------------------------------------------

        List<OrderItem> orderItems = [
            SELECT Id,
                   Product2Id,
                   Product2.Name,
                   Product2.ProductCode,
                   Product2.Product_Image_URL__c,
                   Product2.Collection__r.Name,
                   Quantity,
                   UnitPrice,
                   TotalPrice
            FROM OrderItem
            WHERE OrderId = :orderRecord.Id
            ORDER BY CreatedDate
        ];


        // -----------------------------------------------------
        // BUILD CART RESULT
        // -----------------------------------------------------

        CartResult result =
            new CartResult();

        result.orderId =
            orderRecord.Id;

        result.status =
            orderRecord.Status;

        result.totalAmount = 0;


        Set<Id> productIds = new Set<Id>();
        for (OrderItem item : orderItems) {
            productIds.add(item.Product2Id);
        }

        Map<Id, Decimal> stockByProduct =
            availableByProduct(productIds, orderRecord.Id);


        for (OrderItem item : orderItems) {

            CartItemResult itemResult =
                new CartItemResult();

            itemResult.orderItemId =
                item.Id;

            itemResult.productId =
                item.Product2Id;

            itemResult.productName =
                item.Product2.Name;

            itemResult.productCode =
                item.Product2.ProductCode;

            itemResult.productImageUrl =
                item.Product2.Product_Image_URL__c;

            itemResult.collectionName =
                item.Product2.Collection__r != null
                    ? item.Product2.Collection__r.Name
                    : null;

            itemResult.quantity =
                item.Quantity;

            itemResult.unitPrice =
                item.UnitPrice;

            itemResult.totalPrice =
                item.TotalPrice;

            itemResult.availableStock =
                stockByProduct.get(item.Product2Id);

            result.items.add(itemResult);


            if (item.TotalPrice != null) {

                result.totalAmount +=
                    item.TotalPrice;
            }
        }


        return result;
    }


    // =========================================================
    // DECREASE QUANTITY
    // =========================================================

    public static CartResult decreaseQuantity(
        Id productId
    ) {

        if (productId == null) {

            throw new IllegalArgumentException(
                'Product Id is required.'
            );
        }


        Order cartOrder =
            getCart();


        if (cartOrder == null) {

            throw new IllegalArgumentException(
                'Cart does not exist.'
            );
        }


        List<OrderItem> items = [
            SELECT Id,
                   Product2Id,
                   Quantity
            FROM OrderItem
            WHERE OrderId = :cartOrder.Id
            AND Product2Id = :productId
            LIMIT 1
        ];


        if (items.isEmpty()) {

            throw new IllegalArgumentException(
                'Product is not present in the cart.'
            );
        }


        OrderItem existingItem =
            items[0];


        if (existingItem.Quantity <= 1) {

            delete existingItem;

        } else {

            // Create a fresh sparse sObject for DML.
            // This avoids carrying calculated/read-only
            // OrderItem fields into the update operation.

            OrderItem itemToUpdate =
                new OrderItem(
                    Id = existingItem.Id,
                    Quantity = existingItem.Quantity - 1
                );

            update itemToUpdate;
        }


        return getCurrentCart();
    }


    // =========================================================
    // REMOVE FROM CART
    // =========================================================

    public static CartResult removeFromCart(
        Id productId
    ) {

        if (productId == null) {

            throw new IllegalArgumentException(
                'Product Id is required.'
            );
        }


        Order cartOrder =
            getCart();


        if (cartOrder == null) {

            throw new IllegalArgumentException(
                'Cart does not exist.'
            );
        }


        List<OrderItem> items = [
            SELECT Id,
                   Product2Id
            FROM OrderItem
            WHERE OrderId = :cartOrder.Id
            AND Product2Id = :productId
            LIMIT 1
        ];


        if (items.isEmpty()) {

            throw new IllegalArgumentException(
                'Product is not present in the cart.'
            );
        }


        delete items[0];


        return getCurrentCart();
    }
}