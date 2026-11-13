@RestResource(urlMapping='/razorpay/webhook-debug/*')
global without sharing class RazorpayWebhookDebugEndpoint {

    @HttpPost
    global static void debugWebhook() {

        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        String rawPayload =
            request.requestBody == null
                ? null
                : request.requestBody.toString();

        String receivedSignature =
            request.headers.get('X-Razorpay-Signature');

        UJJAYINI_Integration_Settings__c settings =
            UJJAYINI_Integration_Settings__c.getOrgDefaults();

        String secret =
            settings == null
                ? null
                : settings.Razorpay_Webhook_Secret__c;

        String calculatedSignature = null;

        if (
            rawPayload != null &&
            secret != null
        ) {
            Blob generatedSignature =
                Crypto.generateMac(
                    'HmacSHA256',
                    Blob.valueOf(rawPayload),
                    Blob.valueOf(secret)
                );

            calculatedSignature =
                EncodingUtil.convertToHex(
                    generatedSignature
                ).toLowerCase();
        }

        response.statusCode = 200;
        response.addHeader(
            'Content-Type',
            'application/json'
        );

        response.responseBody =
            Blob.valueOf(
                JSON.serialize(
                    new Map<String, Object>{
                        'bodyLength' =>
                            rawPayload == null
                                ? 0
                                : rawPayload.length(),

                        'receivedSignature' =>
                            receivedSignature,

                        'calculatedSignature' =>
                            calculatedSignature,

                        'signaturesMatch' =>
                            calculatedSignature != null &&
                            receivedSignature != null &&
                            calculatedSignature.toLowerCase() ==
                                receivedSignature.toLowerCase()
                    }
                )
            );
    }
}