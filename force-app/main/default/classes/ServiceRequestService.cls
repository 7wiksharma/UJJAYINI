public without sharing class ServiceRequestService {

    /*
     * Used only by tests: lets a test choose the customer Contact
     * without creating a real Experience Cloud user.
     */
    @TestVisible
    private static Id testContactId;


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

        @AuraEnabled
        public Id assetId;

        @AuraEnabled
        public String caseStatus;

        @AuraEnabled
        public Boolean isClosed;

        @AuraEnabled
        public Datetime closedDate;
    }

    private class CurrentCustomer {

        public Id contactId;

        public Id accountId;
    }


    // =========================================================
    // CREATE REQUEST (existing signature, no specific watch)
    // =========================================================

    public static ServiceRequestResult createRequest(
        String serviceType,
        String priority,
        String description
    ) {

        return createRequest(
            serviceType,
            priority,
            description,
            null
        );
    }


    // =========================================================
    // CREATE REQUEST (optionally for one of the customer's watches)
    // =========================================================

    public static ServiceRequestResult createRequest(
        String serviceType,
        String priority,
        String description,
        Id assetId
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

        CurrentCustomer customer =
            getCurrentCustomer();

        if (customer.contactId == null) {
            throw new IllegalArgumentException(
                'The current user is not associated with a Contact.'
            );
        }

        /*
         * The Asset id comes from the browser, so it is never
         * trusted: it must belong to THIS customer's Account.
         */
        Asset ownedAsset = null;

        if (assetId != null) {

            ownedAsset =
                findOwnedAsset(
                    assetId,
                    customer.accountId
                );
        }

        String caseSubject =
            'UJJAYINI Service Request';

        if (ownedAsset != null) {

            String watchName =
                ownedAsset.Product2 != null
                    ? ownedAsset.Product2.Name
                    : ownedAsset.Name;

            caseSubject =
                caseSubject + ' - ' + watchName;
        }

        Case serviceCase = new Case(
            ContactId = customer.contactId,
            Origin = 'Web',
            Subject = caseSubject,
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
            customer.contactId;

        request.Asset__c =
            ownedAsset != null
                ? ownedAsset.Id
                : null;

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


    // =========================================================
    // MY SERVICE REQUESTS
    // =========================================================

    public static List<ServiceRequestListResult>
        getMyServiceRequests() {

        CurrentCustomer customer =
            getCurrentCustomer();

        if (customer.contactId == null) {
            return new List<ServiceRequestListResult>();
        }

        List<Service_Request__c> requests = [
            SELECT Id,
                   Case__c,
                   Customer__c,
                   Asset__c,
                   Priority__c,
                   Service_Description__c,
                   Service_Request_Date__c,
                   Service_Resolution__c,
                   Service_Type__c
            FROM Service_Request__c
            WHERE Customer__c = :customer.contactId
            WITH SYSTEM_MODE
            ORDER BY Service_Request_Date__c DESC,
                     CreatedDate DESC
        ];

        Set<Id> caseIds = new Set<Id>();

        for (Service_Request__c request : requests) {
            if (request.Case__c != null) {
                caseIds.add(request.Case__c);
            }
        }

        Map<Id, Case> casesById =
            new Map<Id, Case>();

        if (!caseIds.isEmpty()) {

            casesById = new Map<Id, Case>([
                SELECT Id,
                       Status,
                       IsClosed,
                       ClosedDate
                FROM Case
                WHERE Id IN :caseIds
                WITH SYSTEM_MODE
            ]);
        }

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

            result.assetId =
                request.Asset__c;

            Case relatedCase =
                casesById.get(request.Case__c);

            if (relatedCase != null) {

                result.caseStatus =
                    relatedCase.Status;

                result.isClosed =
                    relatedCase.IsClosed;

                result.closedDate =
                    relatedCase.ClosedDate;
            }

            results.add(result);
        }

        return results;
    }


    // =========================================================
    // HELPERS
    // =========================================================

    private static CurrentCustomer getCurrentCustomer() {

        CurrentCustomer customer =
            new CurrentCustomer();

        if (
            Test.isRunningTest() &&
            testContactId != null
        ) {

            customer.contactId =
                testContactId;

            List<Contact> contacts = [
                SELECT Id,
                       AccountId
                FROM Contact
                WHERE Id = :testContactId
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            customer.accountId =
                contacts.isEmpty()
                    ? null
                    : contacts[0].AccountId;

            return customer;
        }

        User currentUser = [
            SELECT Id,
                   ContactId,
                   Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        customer.contactId =
            currentUser.ContactId;

        customer.accountId =
            currentUser.ContactId == null
                ? null
                : currentUser.Contact.AccountId;

        return customer;
    }


    private static Asset findOwnedAsset(
        Id assetId,
        Id accountId
    ) {

        if (accountId == null) {
            throw new IllegalArgumentException(
                'The selected timepiece was not found in your collection.'
            );
        }

        List<Asset> assets = [
            SELECT Id,
                   Name,
                   Product2.Name
            FROM Asset
            WHERE Id = :assetId
            AND AccountId = :accountId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (assets.isEmpty()) {
            throw new IllegalArgumentException(
                'The selected timepiece was not found in your collection.'
            );
        }

        return assets[0];
    }
}