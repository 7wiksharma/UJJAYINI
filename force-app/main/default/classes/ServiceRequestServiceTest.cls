@IsTest
private class ServiceRequestServiceTest {

    @IsTest
    static void createRequest_rejectsUserWithoutContact() {

        Test.startTest();

        try {

            ServiceRequestService.createRequest(
                'Repair',
                'High',
                'Test service request'
            );

            System.assert(
                false,
                'Expected Contact validation exception.'
            );

        } catch (Exception e) {

            System.assert(
                e.getMessage().contains(
                    'current user is not associated with a Contact'
                ),
                'Unexpected error: ' + e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void createRequest_rejectsMissingDescription() {

        Test.startTest();

        try {

            ServiceRequestService.createRequest(
                'Repair',
                'Medium',
                ''
            );

            System.assert(
                false,
                'Expected validation exception.'
            );

        } catch (Exception e) {

            System.assert(
                e.getMessage().contains(
                    'Service description is required.'
                ),
                'Unexpected error: ' + e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void getMyServiceRequests_returnsList() {

        Test.startTest();

        List<ServiceRequestService.ServiceRequestListResult> results =
            ServiceRequestService.getMyServiceRequests();

        Test.stopTest();

        System.assertNotEquals(
            null,
            results,
            'Service request results should not be null.'
        );
    }
}