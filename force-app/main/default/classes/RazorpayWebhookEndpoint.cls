@RestResource(urlMapping='/razorpay/webhook/*')
global with sharing class RazorpayWebhookEndpoint {

    @HttpPost
    global static void receiveWebhook() {

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

        /*
         * The event type will be extracted from the
         * Razorpay payload by the webhook service.
         */
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

        } catch (Exception e) {

            response.statusCode = 400;

            response.addHeader(
                'Content-Type',
                'application/json'
            );

            response.responseBody =
                Blob.valueOf(
                    JSON.serialize(
                        new Map<String, Object>{
                            'success' => false,
                            'error' => e.getMessage()
                        }
                    )
                );
        }
    }
}