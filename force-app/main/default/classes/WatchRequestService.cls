public without sharing class WatchRequestService {

    public class WatchRequestInput {
        public Id watchId;
        public String requestType;
        public Integer requestedQuantity;
        public String customerNote;
    }

    public class WatchRequestResult {
        @AuraEnabled
        public Id requestId;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String message;
    }


    public static WatchRequestResult createRequest(
        WatchRequestInput input
    ) {

        if (input == null) {
            throw new IllegalArgumentException(
                'Watch request is required.'
            );
        }

        if (input.watchId == null) {
            throw new IllegalArgumentException(
                'Watch is required.'
            );
        }

        if (String.isBlank(input.requestType)) {
            throw new IllegalArgumentException(
                'Request type is required.'
            );
        }

        if (
            input.requestedQuantity == null ||
            input.requestedQuantity <= 0
        ) {
            throw new IllegalArgumentException(
                'Requested quantity must be greater than zero.'
            );
        }

        Set<String> allowedRequestTypes =
            new Set<String>{
                'Notify Me',
                'Pre-Order',
                'Custom Request'
            };

        if (!allowedRequestTypes.contains(
            input.requestType
        )) {
            throw new IllegalArgumentException(
                'Invalid request type.'
            );
        }


        /*
         * Get the logged-in user's Contact.
         */
        User currentUser = [
            SELECT Id,
                   ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (currentUser.ContactId == null) {
            throw new IllegalArgumentException(
                'The current user is not associated with a Contact.'
            );
        }


        /*
         * Verify the requested Product exists.
         */
        List<Product2> products = [
            SELECT Id,
                   Name,
                   IsActive
            FROM Product2
            WHERE Id = :input.watchId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (products.isEmpty()) {
            throw new IllegalArgumentException(
                'The requested watch could not be found.'
            );
        }


        /*
         * Prevent duplicate active requests
         * for the same customer and watch.
         */
        List<Watch_Request__c> existingRequests = [
            SELECT Id,
                   Status__c
            FROM Watch_Request__c
            WHERE Customer__c = :currentUser.ContactId
            AND Watch__c = :input.watchId
            AND Status__c IN (
                'New',
                'In Progress'
            )
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (!existingRequests.isEmpty()) {
            throw new IllegalArgumentException(
                'You already have an active request for this watch.'
            );
        }


        Watch_Request__c request =
            new Watch_Request__c();

        request.Customer__c =
            currentUser.ContactId;

        request.Watch__c =
            input.watchId;

        request.Request_Type__c =
            input.requestType;

        request.Requested_Quantity__c =
            input.requestedQuantity;

        request.Customer_Note__c =
            input.customerNote;

        request.Status__c =
            'New';

        request.Requested_Date__c =
            System.now();


        Database.insert(
            request,
            AccessLevel.SYSTEM_MODE
        );


        WatchRequestResult result =
            new WatchRequestResult();

        result.requestId =
            request.Id;

        result.status =
            'New';

        result.message =
            'Your watch request has been submitted successfully.';

        return result;
    }
}