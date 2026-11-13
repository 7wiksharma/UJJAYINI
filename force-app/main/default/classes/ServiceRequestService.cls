public without sharing class ServiceRequestService {

    public class ServiceRequestResult {

        @AuraEnabled
        public Id serviceRequestId;

        @AuraEnabled
        public Id caseId;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String message;
    }

    public class ServiceRequestListResult {

        @AuraEnabled
        public Id serviceRequestId;

        @AuraEnabled
        public Id caseId;

        @AuraEnabled
        public String serviceType;

        @AuraEnabled
        public String priority;

        @AuraEnabled
        public String description;

        @AuraEnabled
        public Date requestDate;

        @AuraEnabled
        public String resolution;
    }

    public static ServiceRequestResult createRequest(
        String serviceType,
        String priority,
        String description
    ) {

        if (String.isBlank(serviceType)) {
            throw new IllegalArgumentException(
                'Service type is required.'
            );
        }

        if (String.isBlank(priority)) {
            throw new IllegalArgumentException(
                'Priority is required.'
            );
        }

        if (String.isBlank(description)) {
            throw new IllegalArgumentException(
                'Service description is required.'
            );
        }

        Set<String> allowedServiceTypes =
            new Set<String>{
                'Repair',
                'Maintenance',
                'Inspection',
                'Warranty Claim',
                'Replacement',
                'Other'
            };

        if (!allowedServiceTypes.contains(serviceType)) {
            throw new IllegalArgumentException(
                'Invalid service type.'
            );
        }

        Set<String> allowedPriorities =
            new Set<String>{
                'Low',
                'Medium',
                'High',
                'Urgent'
            };

        if (!allowedPriorities.contains(priority)) {
            throw new IllegalArgumentException(
                'Invalid priority.'
            );
        }

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

        Case serviceCase = new Case(
            ContactId = currentUser.ContactId,
            Origin = 'Web',
            Subject = 'UJJAYINI Service Request',
            Description = description,
            Priority = priority,
            Status = 'New'
        );

        Database.insert(
            serviceCase,
            AccessLevel.SYSTEM_MODE
        );

        Service_Request__c request =
            new Service_Request__c();

        request.Case__c =
            serviceCase.Id;

        request.Customer__c =
            currentUser.ContactId;

        request.Priority__c =
            priority;

        request.Service_Description__c =
            description;

        request.Service_Request_Date__c =
            Date.today();

        request.Service_Type__c =
            serviceType;

        Database.insert(
            request,
            AccessLevel.SYSTEM_MODE
        );

        ServiceRequestResult result =
            new ServiceRequestResult();

        result.serviceRequestId =
            request.Id;

        result.caseId =
            serviceCase.Id;

        result.status =
            'New';

        result.message =
            'Your service request has been submitted successfully.';

        return result;
    }

    public static List<ServiceRequestListResult>
        getMyServiceRequests() {

        User currentUser = [
            SELECT Id,
                   ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (currentUser.ContactId == null) {
            return new List<ServiceRequestListResult>();
        }

        List<Service_Request__c> requests = [
            SELECT Id,
                   Case__c,
                   Customer__c,
                   Priority__c,
                   Service_Description__c,
                   Service_Request_Date__c,
                   Service_Resolution__c,
                   Service_Type__c
            FROM Service_Request__c
            WHERE Customer__c = :currentUser.ContactId
            WITH SYSTEM_MODE
            ORDER BY Service_Request_Date__c DESC,
                     CreatedDate DESC
        ];

        List<ServiceRequestListResult> results =
            new List<ServiceRequestListResult>();

        for (Service_Request__c request : requests) {

            ServiceRequestListResult result =
                new ServiceRequestListResult();

            result.serviceRequestId =
                request.Id;

            result.caseId =
                request.Case__c;

            result.serviceType =
                request.Service_Type__c;

            result.priority =
                request.Priority__c;

            result.description =
                request.Service_Description__c;

            result.requestDate =
                request.Service_Request_Date__c;

            result.resolution =
                request.Service_Resolution__c;

            results.add(result);
        }

        return results;
    }
}