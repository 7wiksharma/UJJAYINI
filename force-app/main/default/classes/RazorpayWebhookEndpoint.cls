@RestResource(urlMapping='/razorpay/webhook/*')
global with sharing class RazorpayWebhookEndpoint {

    @HttpPost
    global static void receiveWebhook() {
          System.debug(
    'UJJAYINI WEBHOOK USER = ' +
    UserInfo.getUserName() +
    ' | USER ID = ' +
    UserInfo.getUserId() +
    ' | USER TYPE = ' +
    UserInfo.getUserType() +
    ' | PROFILE ID = ' +
    UserInfo.getProfileId()
);
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        String rawPayload = request.requestBody == null
            ? null
            : request.requestBody.toString();

        String signature =
            request.headers.get('X-Razorpay-Signature');

        String eventId =
            request.headers.get('X-Razorpay-Event-Id');

        RazorpayWebhookService.WebhookRequest webhookRequest =
            new RazorpayWebhookService.WebhookRequest();

        webhookRequest.eventId = eventId;
        webhookRequest.rawPayload = rawPayload;
        webhookRequest.signature = signature;
        webhookRequest.eventType = 'Other';

        try {

            RazorpayWebhookService.WebhookResult result =
                RazorpayWebhookService.processWebhook(
                    webhookRequest
                );

            response.statusCode = 200;

            response.addHeader(
                'Content-Type',
                'application/json'
            );

            response.responseBody =
                Blob.valueOf(
                    JSON.serialize(
                        new Map<String, Object>{
                            'success' => true,
                            'webhookEventId' =>
                                result.webhookEventId,
                            'status' =>
                                result.processingStatus
                        }
                    )
                );

        } catch(Exception e) {

    System.debug(
        LoggingLevel.ERROR,
        'UJJAYINI WEBHOOK ERROR: ' +
        e.getTypeName() +
        ' | ' +
        e.getMessage() +
        ' | ' +
        e.getStackTraceString()
    );

    response.statusCode = 400;
    response.addHeader('Content-Type','application/json');

    response.responseBody = Blob.valueOf(
        JSON.serialize(
            new Map<String,Object>{
                'success' => false,
                'error' => e.getMessage(),
                'type' => e.getTypeName(),
                'stackTrace' => e.getStackTraceString()
            }
        )
    );
}
    }
}