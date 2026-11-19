@IsTest
private class ServiceRequestAssetTest {

    private static Contact createCustomer(String lastName) {

        Account account = new Account(
            Name = lastName + ' Household'
        );

        insert account;

        Contact contact = new Contact(
            LastName = lastName,
            AccountId = account.Id
        );

        insert contact;

        return contact;
    }


    private static Asset createAsset(Id accountId) {

        Asset asset = new Asset(
            Name = 'UJJAYINI Test Watch',
            AccountId = accountId,
            Quantity = 1,
            Status = 'Purchased',
            SerialNumber = 'UJJAYINI-TEST'
        );

        insert asset;

        return asset;
    }


    @IsTest
    static void requestIsLinkedToTheCustomersOwnAsset() {

        Contact customer = createCustomer('Owner');
        Asset asset = createAsset(customer.AccountId);

        ServiceRequestService.testContactId = customer.Id;

        ServiceRequestService.ServiceRequestResult result =
            ServiceRequestService.createRequest(
                'Maintenance',
                'Medium',
                'Please inspect the movement.',
                asset.Id
            );

        Service_Request__c saved = [
            SELECT Asset__c,
                   Customer__c,
                   Case__c
            FROM Service_Request__c
            WHERE Id = :result.serviceRequestId
        ];

        System.assertEquals(asset.Id, saved.Asset__c);
        System.assertEquals(customer.Id, saved.Customer__c);
        System.assertNotEquals(null, saved.Case__c);

        Case savedCase = [
            SELECT Subject
            FROM Case
            WHERE Id = :saved.Case__c
        ];

        System.assert(
            savedCase.Subject.contains('UJJAYINI Service Request'),
            'Case subject should identify the service request.'
        );
    }


    @IsTest
    static void anotherCustomersAssetIsRejected() {

        Contact owner = createCustomer('Owner');
        Contact stranger = createCustomer('Stranger');

        Asset ownersAsset = createAsset(owner.AccountId);

        // Logged in as a DIFFERENT customer.
        ServiceRequestService.testContactId = stranger.Id;

        Boolean rejected = false;

        try {

            ServiceRequestService.createRequest(
                'Repair',
                'High',
                'Trying to use someone else\'s watch.',
                ownersAsset.Id
            );

        } catch (IllegalArgumentException e) {

            rejected = true;

            System.assert(
                e.getMessage().contains('not found in your collection')
            );
        }

        System.assertEquals(true, rejected);

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Service_Request__c]
        );
    }


    @IsTest
    static void requestWithoutAssetStillWorks() {

        Contact customer = createCustomer('Owner');

        ServiceRequestService.testContactId = customer.Id;

        ServiceRequestService.ServiceRequestResult result =
            ServiceRequestService.createRequest(
                'Inspection',
                'Low',
                'General enquiry.'
            );

        Service_Request__c saved = [
            SELECT Asset__c
            FROM Service_Request__c
            WHERE Id = :result.serviceRequestId
        ];

        System.assertEquals(null, saved.Asset__c);
    }


    @IsTest
    static void historyCarriesTheAssetAndCaseStatus() {

        Contact customer = createCustomer('Owner');
        Asset asset = createAsset(customer.AccountId);

        ServiceRequestService.testContactId = customer.Id;

        ServiceRequestService.createRequest(
            'Repair',
            'Medium',
            'Crown is loose.',
            asset.Id
        );

        List<ServiceRequestService.ServiceRequestListResult> history =
            ServiceRequestService.getMyServiceRequests();

        System.assertEquals(1, history.size());
        System.assertEquals(asset.Id, history[0].assetId);
        System.assertEquals(false, history[0].isClosed);
        System.assertNotEquals(null, history[0].caseStatus);
    }


    @IsTest
    static void controllerPassesTheAssetThrough() {

        Contact customer = createCustomer('Owner');
        Asset asset = createAsset(customer.AccountId);

        ServiceRequestService.testContactId = customer.Id;

        ServiceRequestService.ServiceRequestResult result =
            UJJAYINIServiceRequestController.createRequest(
                'Repair',
                'Medium',
                'Crown is loose.',
                asset.Id
            );

        System.assertNotEquals(null, result.serviceRequestId);
    }
}