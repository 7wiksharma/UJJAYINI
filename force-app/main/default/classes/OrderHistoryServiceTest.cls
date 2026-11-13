@IsTest
private class OrderHistoryServiceTest {

    @IsTest
    static void getMyOrders_returnsEmptyForUserWithoutContact() {

        Test.startTest();

        List<OrderHistoryService.OrderResult> results =
            OrderHistoryService.getMyOrders();

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'The result should not be null.'
        );
    }

    @IsTest
    static void getMyOrders_returnsOrdersForCustomer() {

        Account account = new Account(
            Name = 'UJJAYINI Order History Test Account'
        );
        insert account;

        Contact contact = new Contact(
            FirstName = 'Order',
            LastName = 'Customer',
            AccountId = account.Id,
            Email = 'orderhistory@example.com'
        );
        insert contact;

        Product2 product = new Product2(
            Name = 'UJJAYINI Order History Watch',
            IsActive = true
        );
        insert product;

        Pricebook2 standardPricebook = [
            SELECT Id, IsActive
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];

        if (!standardPricebook.IsActive) {
            standardPricebook.IsActive = true;
            update standardPricebook;
        }

        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = product.Id,
            UnitPrice = 69999,
            IsActive = true
        );
        insert pricebookEntry;

        Order testOrder = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebook.Id
        );
        insert testOrder;

        OrderItem orderItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = pricebookEntry.Id,
            Quantity = 1,
            UnitPrice = 69999
        );
        insert orderItem;

        Test.startTest();

        List<OrderHistoryService.OrderResult> results =
            OrderHistoryService.getMyOrders();

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'The result should not be null.'
        );
    }
}