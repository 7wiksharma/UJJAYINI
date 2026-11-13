public with sharing class UJJAYINIWatchRequestController {

    @AuraEnabled
    public static WatchRequestService.WatchRequestResult createRequest(
        Id watchId,
        String requestType,
        Integer requestedQuantity,
        String customerNote
    ) {

        if (watchId == null) {
            throw new AuraHandledException(
                'Watch Id is required.'
            );
        }

        try {

            WatchRequestService.WatchRequestInput input =
                new WatchRequestService.WatchRequestInput();

            input.watchId =
                watchId;

            input.requestType =
                requestType;

            input.requestedQuantity =
                requestedQuantity;

            input.customerNote =
                customerNote;

            return WatchRequestService.createRequest(
                input
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}