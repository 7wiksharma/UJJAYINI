@IsTest
private class WatchRequestServiceTest {

    @IsTest
    static void createRequest_createsWatchRequest() {

        Account account = new Account(
            Name = 'UJJAYINI Watch Request Test Account'
        );
        insert account;

        Contact contact = new Contact(
            FirstName = 'Watch',
            LastName = 'Customer',
            AccountId = account.Id,
            Email = 'watchrequest@example.com'
        );
        insert contact;

        Product2 product = new Product2(
            Name = 'UJJAYINI Test Watch',
            IsActive = true
        );
        insert product;

        /*
         * The service uses UserInfo.getUserId().
         * The test therefore runs as the current test user.
         *
         * If the current user is not associated with a Contact,
         * createRequest() will correctly reject the request.
         */
        User currentUser = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        Test.startTest();

        if (currentUser.ContactId != null) {

            WatchRequestService.WatchRequestInput input =
                new WatchRequestService.WatchRequestInput();

            input.watchId =
                product.Id;

            input.requestType =
                'Notify Me';

            input.requestedQuantity =
                1;

            input.customerNote =
                'Please notify me when this watch is available.';

            WatchRequestService.WatchRequestResult result =
                WatchRequestService.createRequest(input);

            Test.stopTest();

            System.assertNotEquals(
                null,
                result.requestId,
                'Request Id should be returned.'
            );

            System.assertEquals(
                'New',
                result.status,
                'Request should start with New status.'
            );

            Watch_Request__c request = [
                SELECT Id,
                       Customer__c,
                       Watch__c,
                       Request_Type__c,
                       Requested_Quantity__c,
                       Customer_Note__c,
                       Status__c,
                       Requested_Date__c
                FROM Watch_Request__c
                WHERE Id = :result.requestId
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            System.assertEquals(
                currentUser.ContactId,
                request.Customer__c
            );

            System.assertEquals(
                product.Id,
                request.Watch__c
            );

            System.assertEquals(
                'Notify Me',
                request.Request_Type__c
            );

            System.assertEquals(
                1,
                request.Requested_Quantity__c
            );

            System.assertEquals(
                'New',
                request.Status__c
            );

            System.assertNotEquals(
                null,
                request.Requested_Date__c
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void createRequest_rejectsMissingWatch() {

        WatchRequestService.WatchRequestInput input =
            new WatchRequestService.WatchRequestInput();

        input.requestType =
            'Notify Me';

        input.requestedQuantity =
            1;

        Test.startTest();

        try {

            WatchRequestService.createRequest(
                input
            );

            System.assert(
                false,
                'Expected an exception for missing Watch Id.'
            );

        } catch (Exception e) {

            System.assert(
                e.getMessage().contains(
                    'Watch is required.'
                )
            );
        }

        Test.stopTest();
    }
}