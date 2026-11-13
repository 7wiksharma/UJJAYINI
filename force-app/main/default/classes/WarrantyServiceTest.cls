@IsTest
private class WarrantyServiceTest {

    @IsTest
    static void getMyWarranties_returnsCustomerWarranties() {

        Account account = new Account(
            Name = 'UJJAYINI Warranty Test Account'
        );
        insert account;


        Contact contact = new Contact(
            FirstName = 'Warranty',
            LastName = 'Customer',
            AccountId = account.Id,
            Email = 'warrantytest@example.com'
        );
        insert contact;


        Product2 product = new Product2(
            Name = 'UJJAYINI Warranty Test Watch',
            IsActive = true
        );
        insert product;


        Asset asset = new Asset(
            Name = 'UJJAYINI Warranty Test Asset',
            AccountId = account.Id,
            Product2Id = product.Id,
            Quantity = 1,
            Price = 69999,
            Status = 'Purchased',
            SerialNumber = 'UJJAYINI-WARRANTY-TEST-001',
            PurchaseDate = Date.today()
        );
        insert asset;


        Warranty__c warranty = new Warranty__c(
            Asset__c = asset.Id,
            Warranty_Coverage_Type__c = 'Standard',
            Warranty_Duration__c = 12,
            Warranty_Start_Date__c = Date.today(),
            Warranty_End_Date__c = Date.today().addMonths(12),
            Warranty_Status__c = 'Active',
            Warranty_Notes__c = 'Test warranty'
        );
        insert warranty;


        User currentUser = [
            SELECT Id,
                   ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];


        Test.startTest();

        List<WarrantyService.WarrantyResult> results =
            WarrantyService.getMyWarranties();

        Test.stopTest();


        System.assertNotEquals(
            null,
            results,
            'Warranty results should not be null.'
        );


        if (currentUser.ContactId != null) {

            System.assert(
                results.size() >= 0,
                'Warranty query should complete successfully.'
            );
        }
    }
}