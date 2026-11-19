public with sharing class UJJAYINIServiceRequestController {

    @AuraEnabled
    public static ServiceRequestService.ServiceRequestResult createRequest(
        String serviceType,
        String priority,
        String description,
        Id assetId
    ) {

        try {

            return ServiceRequestService.createRequest(
                serviceType,
                priority,
                description,
                assetId
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ServiceRequestService.ServiceRequestListResult>
        getMyServiceRequests() {

        try {

            return ServiceRequestService.getMyServiceRequests();

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}