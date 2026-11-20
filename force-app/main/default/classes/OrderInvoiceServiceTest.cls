@IsTest
private class OrderInvoiceServiceTest {

    @TestSetup
    static void setupData() {

        Account account = new Account(Name = 'Invoice Customer');
        insert account;

        Contact contact = new Contact(
            LastName = 'Collector',
            Email = 'collector@example.com',
            AccountId = account.Id
        );
        insert contact;

        Product2 product = new Product2(
            Name = 'Invoice Test Watch',
            ProductCode = 'UJ-TEST-1',
            IsActive = true
        );
        insert product;

        Id standardPricebookId = Test.getStandardPricebookId();

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 165000,
            IsActive = true
        );
        insert entry;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = standardPricebookId,
            BillToContactId = contact.Id,
            ShipToContactId = contact.Id,
            ShippingStreet = '12 Mahakal Marg',
            ShippingCity = 'Ujjain',
            ShippingState = 'Madhya Pradesh',
            ShippingPostalCode = '456001',
            ShippingCountry = 'India'
        );
        insert orderRecord;

        insert new OrderItem(
            OrderId = orderRecord.Id,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = 165000
        );

        orderRecord.Status = 'Activated';
        update orderRecord;

        insert new Payment__c(
            Order__c = orderRecord.Id,
            Amount__c = 165000,
            Payment_Status__c = 'Captured',
            Gateway_Order_ID__c = 'plink_INV1',
            Gateway_Payment_ID__c = 'pay_INV1',
            Paid_At__c = System.now()
        );
    }


    @IsTest
    static void invoiceContainsTheOrder() {

        Order orderRecord = [SELECT Id, OrderNumber FROM Order LIMIT 1];

        String html = OrderInvoiceService.buildInvoiceHtml(orderRecord.Id);

        System.assert(html.contains('UJ-INV-' + orderRecord.OrderNumber));
        System.assert(html.contains('Invoice Test Watch'));
        System.assert(html.contains('INR 1,65,000.00'));
        System.assert(!html.contains('CREDIT NOTE'));

        System.assertNotEquals(
            null,
            OrderInvoiceService.buildInvoicePdf(orderRecord.Id)
        );
    }


    @IsTest
    static void cancelledInvoiceShowsCreditNote() {

        Order orderRecord = [SELECT Id FROM Order LIMIT 1];

        orderRecord.Is_Cancelled__c = true;
        orderRecord.Cancelled_At__c = System.now();
        update orderRecord;

        String html = OrderInvoiceService.buildInvoiceHtml(orderRecord.Id);

        System.assert(html.contains('CREDIT NOTE'));
        System.assert(html.contains('CANCELLED'));
    }


    @IsTest
    static void invoiceEmailIsSentOnlyOnce() {

        Order orderRecord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();

        Boolean first = OrderInvoiceService.sendInvoiceEmail(orderRecord.Id);
        Boolean second = OrderInvoiceService.sendInvoiceEmail(orderRecord.Id);

        Test.stopTest();

        System.assertEquals(true, first);
        System.assertEquals(false, second);

        System.assertNotEquals(
            null,
            [SELECT Invoice_Emailed_At__c FROM Order WHERE Id = :orderRecord.Id]
                .Invoice_Emailed_At__c
        );
    }


    @IsTest
    static void indianNumberFormat() {

        System.assertEquals('INR 1,65,000.00', OrderInvoiceService.formatInr(165000));
        System.assertEquals('INR 999.50', OrderInvoiceService.formatInr(999.5));
        System.assertEquals('INR 12,34,567.00', OrderInvoiceService.formatInr(1234567));
    }


    @IsTest
    static void ownerCanDownloadInvoice() {

        Order orderRecord = [SELECT Id, AccountId FROM Order LIMIT 1];

        UJJAYINIInvoiceController.testAccountId = orderRecord.AccountId;

        UJJAYINIInvoiceController.InvoiceFile file =
            UJJAYINIInvoiceController.getMyInvoice(orderRecord.Id);

        System.assert(file.fileName.endsWith('.pdf'));
        System.assert(String.isNotBlank(file.base64Pdf));
    }


    @IsTest
    static void anotherCustomerCannotDownloadInvoice() {

        Order orderRecord = [SELECT Id FROM Order LIMIT 1];

        Account stranger = new Account(Name = 'Another Customer');
        insert stranger;

        UJJAYINIInvoiceController.testAccountId = stranger.Id;

        Boolean rejected = false;

        try {

            UJJAYINIInvoiceController.getMyInvoice(orderRecord.Id);

        } catch (AuraHandledException e) {

            rejected = true;
        }

        System.assertEquals(true, rejected);
    }
}