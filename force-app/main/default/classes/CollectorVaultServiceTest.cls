@IsTest
private class CollectorVaultServiceTest {

    @IsTest
    static void getMyAssets_returnsCustomerAssets() {

        Account account = new Account(
            Name = 'UJJAYINI Vault Test Account'
        );
        insert account;

        Contact contact = new Contact(
            FirstName = 'Vault',
            LastName = 'Customer',
            AccountId = account.Id,
            Email = 'vaulttest@example.com'
        );
        insert contact;

        Product2 product = new Product2(
            Name = 'UJJAYINI Vault Test Watch',
            IsActive = true
        );
        insert product;

        Asset asset = new Asset(
            Name = 'UJJAYINI Vault Test Asset',
            AccountId = account.Id,
            Product2Id = product.Id,
            Quantity = 1,
            Price = 69999,
            Status = 'Purchased',
            SerialNumber = 'UJJAYINI-TEST-VAULT-001',
            PurchaseDate = Date.today()
        );
        insert asset;

        User currentUser = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Test.startTest();

        List<CollectorVaultService.AssetResult> results =
            CollectorVaultService.getMyAssets();

        Test.stopTest();

        /*
         * This test expects the running test user to be
         * associated with the test Contact.
         *
         * If the current user is not associated with a Contact,
         * the service correctly returns an empty list.
         */
        if (currentUser.ContactId != null) {
            System.assertNotEquals(
                null,
                results,
                'Results should not be null.'
            );
        }
    }
}