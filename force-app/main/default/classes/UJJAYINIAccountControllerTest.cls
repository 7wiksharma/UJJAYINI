@IsTest
private class UJJAYINIAccountControllerTest {

    private static Contact createCustomer(Integer assets) {

        Account account = new Account(Name = 'Account Page Customer');
        insert account;

        Contact contact = new Contact(
            FirstName = 'Satwik',
            LastName = 'Collector',
            Email = 'collector@example.com',
            AccountId = account.Id
        );
        insert contact;

        List<Asset> records = new List<Asset>();

        for (Integer i = 0; i < assets; i++) {
            records.add(new Asset(
                Name = 'UJJAYINI Asset ' + i,
                AccountId = account.Id,
                Quantity = 1,
                Price = 100000,
                Status = 'Purchased',
                SerialNumber = 'UJJAYINI-TEST-' + i
            ));
        }

        if (!records.isEmpty()) {
            insert records;
        }

        return contact;
    }


    @IsTest
    static void summaryShowsCollectionAndTier() {

        Contact customer = createCustomer(2);

        UJJAYINIAccountController.testContactId = customer.Id;

        UJJAYINIAccountController.AccountSummary summary =
            UJJAYINIAccountController.getMyAccount();

        System.assertEquals('Satwik', summary.firstName);
        System.assertEquals(2, summary.timepiecesOwned);
        System.assertEquals(200000, summary.collectionValue);
        System.assertEquals('Connoisseur', summary.tierName);
        System.assertEquals('Patron of Time', summary.nextTierName);
        System.assertEquals(2, summary.piecesToNextTier);
        System.assertNotEquals(null, summary.memberSince);
    }


    @IsTest
    static void newMemberIsAnInitiate() {

        Contact customer = createCustomer(0);

        UJJAYINIAccountController.testContactId = customer.Id;

        UJJAYINIAccountController.AccountSummary summary =
            UJJAYINIAccountController.getMyAccount();

        System.assertEquals('Initiate', summary.tierName);
        System.assertEquals(1, summary.piecesToNextTier);
        System.assertEquals(0, summary.tierProgress);
    }


    @IsTest
    static void customerCanUpdateDetails() {

        Contact customer = createCustomer(0);

        UJJAYINIAccountController.testContactId = customer.Id;

        UJJAYINIAccountController.AccountSummary summary =
            UJJAYINIAccountController.updateMyDetails(
                '9876543210',
                '12 Mahakal Marg',
                'Ujjain',
                'Madhya Pradesh',
                '456001',
                'India'
            );

        System.assertEquals('9876543210', summary.phone);
        System.assertEquals('Ujjain', summary.city);
    }


    @IsTest
    static void invalidPinIsRejected() {

        Contact customer = createCustomer(0);

        UJJAYINIAccountController.testContactId = customer.Id;

        Boolean rejected = false;

        try {

            UJJAYINIAccountController.updateMyDetails(
                '9876543210', '12 Mahakal Marg', 'Ujjain',
                'Madhya Pradesh', '45', 'India'
            );

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('PIN code'));
        }

        System.assertEquals(true, rejected);
    }


    @IsTest
    static void userWithoutContactIsAskedToSignIn() {

        Boolean rejected = false;

        try {

            UJJAYINIAccountController.getMyAccount();

        } catch (AuraHandledException e) {

            rejected = true;
        }

        System.assertEquals(true, rejected);
    }
}