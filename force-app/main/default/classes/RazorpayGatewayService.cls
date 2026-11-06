public with sharing class RazorpayGatewayService {

    public class CreateOrderRequest {
        public Decimal amount;
        public String currencyCode;
        public String receipt;
    }

    public class CreateOrderResult {
        public String razorpayOrderId;
        public String status;
        public Decimal amount;
        public String currencyCode;
        public String receipt;
    }

    public static CreateOrderResult createOrder(
        CreateOrderRequest request
    ) {

        if (request == null) {
            throw new IllegalArgumentException(
                'Create order request is required.'
            );
        }

        if (request.amount == null || request.amount <= 0) {
            throw new IllegalArgumentException(
                'Order amount must be greater than zero.'
            );
        }

        if (String.isBlank(request.currencyCode)) {
            request.currencyCode = 'INR';
        }

        Decimal amountInPaiseDecimal =
            (request.amount * 100).setScale(0);

        Integer amountInPaise =
            Integer.valueOf(
                String.valueOf(amountInPaiseDecimal)
            );

        HttpRequest httpRequest = new HttpRequest();

        httpRequest.setEndpoint(
            'callout:Razorpay_API/v1/orders'
        );

        httpRequest.setMethod('POST');

        httpRequest.setHeader(
            'Content-Type',
            'application/json'
        );

        Map<String, Object> requestBody =
            new Map<String, Object>();

        requestBody.put(
            'amount',
            amountInPaise
        );

        requestBody.put(
            'currency',
            request.currencyCode
        );

        if (!String.isBlank(request.receipt)) {
            requestBody.put(
                'receipt',
                request.receipt
            );
        }

        httpRequest.setBody(
            JSON.serialize(requestBody)
        );

        Http http = new Http();

        HttpResponse response =
            http.send(httpRequest);

        Integer statusCode =
            response.getStatusCode();

        if (statusCode < 200 || statusCode >= 300) {
            throw new CalloutException(
                'Razorpay order creation failed. ' +
                'Status: ' + statusCode +
                ' | Body: ' + response.getBody()
            );
        }

        Map<String, Object> responseBody =
            (Map<String, Object>) JSON.deserializeUntyped(
                response.getBody()
            );

        CreateOrderResult result =
            new CreateOrderResult();

        result.razorpayOrderId =
            (String) responseBody.get('id');

        result.status =
            (String) responseBody.get('status');

        result.currencyCode =
            (String) responseBody.get('currency');

        result.receipt =
            (String) responseBody.get('receipt');

        Object responseAmount =
            responseBody.get('amount');

        if (responseAmount != null) {
            result.amount =
                Decimal.valueOf(
                    String.valueOf(responseAmount)
                ) / 100;
        }

        return result;
    }
}