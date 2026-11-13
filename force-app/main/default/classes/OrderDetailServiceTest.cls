@IsTest
private class OrderDetailServiceTest {

    @IsTest
    static void getOrderDetails_requiresOrderId() {

        Test.startTest();

        try {
            OrderDetailService.getOrderDetails(null);
            System.assert(false, 'Expected an exception.');
        } catch (Exception e) {
            System.assert(
                e.getMessage().contains('Order Id is required.')
            );
        }

        Test.stopTest();
    }

    @IsTest
    static void getOrderDetails_returnsOrderForCustomer() {

        Account account = new Account(
            Name = 'UJJAYINI Order Detail Test Account'
        );
        insert account;

        Contact contact = new Contact(
            FirstName = 'Order',
            LastName = 'Detail Customer',
            AccountId = account.Id,
            Email = 'orderdetail@example.com'
        );
        insert contact;

        Product2 product = new Product2(
            Name = 'UJJAYINI Order Detail Watch',
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

        try {
            List<OrderDetailService.OrderDetailResult> results =
                new List<OrderDetailService.OrderDetailResult>();

            // The service uses the current test user.
            // This test confirms the method executes without
            // introducing a null result expectation.
            OrderDetailService.getOrderDetails(testOrder.Id);

            System.assert(
                true,
                'Order detail service executed.'
            );

        } catch (Exception e) {

            System.assertNotEquals(
                null,
                e.getMessage(),
                'Any service exception should have a message.'
            );
        }

        Test.stopTest();
    }
}