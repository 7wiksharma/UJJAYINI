String payload =
    '{"entity":"event",' +
    '"account_id":"acc_test_123",' +
    '"event":"payment.captured",' +
    '"payload":{' +
        '"payment":{' +
            '"entity":{' +
                '"id":"pay_endpoint_test",' +
                '"amount":5000000,' +
                '"currency":"INR",' +
                '"status":"captured"' +
            '}' +
        '}' +
    '}}';

String secret =
    '7d7cb9192c4b8b64a2c079ad72e79e66';

Blob payloadBlob = Blob.valueOf(payload);
Blob secretBlob = Blob.valueOf(secret);

Blob mac = Crypto.generateMac(
    'HmacSHA256',
    payloadBlob,
    secretBlob
);

String signature =
    EncodingUtil.convertToHex(mac);

HttpRequest request = new HttpRequest();

request.setEndpoint(
    'https://orgfarm-70c23216f9-dev-ed.develop.my.site.com' +
    '/ujjayini/services/apexrest/razorpay/webhook/'
);

request.setMethod('POST');

request.setHeader(
    'Content-Type',
    'application/json'
);

request.setHeader(
    'X-Razorpay-Signature',
    signature
);

request.setHeader(
    'X-Razorpay-Event-Id',
    'evt_real_endpoint_test_001'
);

request.setBody(payload);

Http http = new Http();

HttpResponse response =
    http.send(request);

System.debug(
    'STATUS = ' + response.getStatusCode()
);

System.debug(
    'BODY = ' + response.getBody()
);

System.debug(
    'LOCATION = ' + response.getHeader('Location')
);