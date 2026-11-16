@IsTest
private class RazorpayGatewayServiceTest {

    private class RazorpayOrderMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            System.assertEquals(
                'POST',
                request.getMethod()
            );

            System.assertEquals(
                'callout:Razorpay_API/v1/orders',
                request.getEndpoint()
            );

            System.assertEquals(
                'application/json',
                request.getHeader('Content-Type')
            );

            Map<String, Object> requestBody =
                (Map<String, Object>) JSON.deserializeUntyped(
                    request.getBody()
                );

            System.assertEquals(
                2500000,
                requestBody.get('amount')
            );

            System.assertEquals(
                'INR',
                requestBody.get('currency')
            );

            System.assertEquals(
                'UJ-TEST-1001',
                requestBody.get('receipt')
            );

            HttpResponse response = new HttpResponse();

            response.setStatusCode(200);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{"id":"order_test_12345",' +
                '"entity":"order",' +
                '"amount":2500000,' +
                '"amount_paid":0,' +
                '"amount_due":2500000,' +
                '"currency":"INR",' +
                '"receipt":"UJ-TEST-1001",' +
                '"status":"created"}'
            );

            return response;
        }
    }


    private class RazorpayErrorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            HttpResponse response = new HttpResponse();

            response.setStatusCode(400);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{"error":{"code":"BAD_REQUEST_ERROR",' +
                '"description":"Invalid order request"}}'
            );

            return response;
        }
    }


    private class RazorpayRefundMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            System.assertEquals(
                'POST',
                request.getMethod()
            );

            System.assertEquals(
                'callout:Razorpay_API/v1/payments/pay_test_12345/refund',
                request.getEndpoint()
            );

            System.assertEquals(
                'application/json',
                request.getHeader('Content-Type')
            );

            Map<String, Object> requestBody =
                (Map<String, Object>) JSON.deserializeUntyped(
                    request.getBody()
                );

            System.assertEquals(
                'UJ-REFUND-1001',
                requestBody.get('receipt')
            );

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{"id":"rfnd_test_12345",' +
                '"entity":"refund",' +
                '"amount":2500000,' +
                '"currency":"INR",' +
                '"payment_id":"pay_test_12345",' +
                '"status":"processed",' +
                '"receipt":"UJ-REFUND-1001"}'
            );

            return response;
        }
    }


    private class RazorpayPartialRefundMock
        implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            System.assertEquals(
                'POST',
                request.getMethod()
            );

            System.assertEquals(
                'callout:Razorpay_API/v1/payments/pay_test_54321/refund',
                request.getEndpoint()
            );

            Map<String, Object> requestBody =
                (Map<String, Object>) JSON.deserializeUntyped(
                    request.getBody()
                );

            System.assertEquals(
                1000000,
                requestBody.get('amount')
            );

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{"id":"rfnd_test_54321",' +
                '"entity":"refund",' +
                '"amount":1000000,' +
                '"currency":"INR",' +
                '"payment_id":"pay_test_54321",' +
                '"status":"processed"}'
            );

            return response;
        }
    }


    private class RazorpayRefundErrorMock
        implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest request) {

            System.assertEquals(
                'POST',
                request.getMethod()
            );

            System.assertEquals(
                'callout:Razorpay_API/v1/payments/pay_test_error/refund',
                request.getEndpoint()
            );

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(400);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{"error":{"code":"BAD_REQUEST_ERROR",' +
                '"description":"Refund failed"}}'
            );

            return response;
        }
    }


    @IsTest
    static void createOrderSuccessfully() {

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayOrderMock()
        );

        RazorpayGatewayService.CreateOrderRequest request =
            new RazorpayGatewayService.CreateOrderRequest();

        request.amount = 25000;
        request.currencyCode = 'INR';
        request.receipt = 'UJ-TEST-1001';

        Test.startTest();

        RazorpayGatewayService.CreateOrderResult result =
            RazorpayGatewayService.createOrder(request);

        Test.stopTest();

        System.assertEquals(
            'order_test_12345',
            result.razorpayOrderId
        );

        System.assertEquals(
            'created',
            result.status
        );

        System.assertEquals(
            25000,
            result.amount
        );

        System.assertEquals(
            'INR',
            result.currencyCode
        );

        System.assertEquals(
            'UJ-TEST-1001',
            result.receipt
        );
    }


    @IsTest
    static void createOrderFailsForInvalidAmount() {

        RazorpayGatewayService.CreateOrderRequest request =
            new RazorpayGatewayService.CreateOrderRequest();

        request.amount = 0;
        request.currencyCode = 'INR';
        request.receipt = 'UJ-TEST-1002';

        Test.startTest();

        try {

            RazorpayGatewayService.createOrder(request);

            System.assert(
                false,
                'Expected invalid amount exception.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Order amount must be greater than zero.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void createOrderFailsWhenRazorpayReturnsError() {

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayErrorMock()
        );

        RazorpayGatewayService.CreateOrderRequest request =
            new RazorpayGatewayService.CreateOrderRequest();

        request.amount = 25000;
        request.currencyCode = 'INR';
        request.receipt = 'UJ-TEST-1003';

        Test.startTest();

        try {

            RazorpayGatewayService.createOrder(request);

            System.assert(
                false,
                'Expected Razorpay API failure.'
            );

        } catch (CalloutException e) {

            System.assert(
                e.getMessage().contains(
                    'Razorpay order creation failed'
                )
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void createFullRefundSuccessfully() {

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayRefundMock()
        );

        RazorpayGatewayService.CreateRefundRequest request =
            new RazorpayGatewayService.CreateRefundRequest();

        request.razorpayPaymentId =
            'pay_test_12345';

        request.receipt =
            'UJ-REFUND-1001';

        /*
         * No amount supplied.
         * This represents a full refund.
         */

        Test.startTest();

        RazorpayGatewayService.CreateRefundResult result =
            RazorpayGatewayService.createRefund(request);

        Test.stopTest();

        System.assertEquals(
            'rfnd_test_12345',
            result.razorpayRefundId
        );

        System.assertEquals(
            'processed',
            result.status
        );

        System.assertEquals(
            25000,
            result.amount
        );

        System.assertEquals(
            'INR',
            result.currencyCode
        );

        System.assertEquals(
            'pay_test_12345',
            result.paymentId
        );

        System.assertEquals(
            'UJ-REFUND-1001',
            result.receipt
        );
    }


    @IsTest
    static void createPartialRefundSuccessfully() {

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayPartialRefundMock()
        );

        RazorpayGatewayService.CreateRefundRequest request =
            new RazorpayGatewayService.CreateRefundRequest();

        request.razorpayPaymentId =
            'pay_test_54321';

        request.amount = 10000;

        Test.startTest();

        RazorpayGatewayService.CreateRefundResult result =
            RazorpayGatewayService.createRefund(request);

        Test.stopTest();

        System.assertEquals(
            'rfnd_test_54321',
            result.razorpayRefundId
        );

        System.assertEquals(
            'processed',
            result.status
        );

        System.assertEquals(
            10000,
            result.amount
        );

        System.assertEquals(
            'INR',
            result.currencyCode
        );

        System.assertEquals(
            'pay_test_54321',
            result.paymentId
        );
    }


    @IsTest
    static void createRefundFailsWhenRazorpayReturnsError() {

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayRefundErrorMock()
        );

        RazorpayGatewayService.CreateRefundRequest request =
            new RazorpayGatewayService.CreateRefundRequest();

        request.razorpayPaymentId =
            'pay_test_error';

        request.amount = 10000;

        Test.startTest();

        try {

            RazorpayGatewayService.createRefund(request);

            System.assert(
                false,
                'Expected Razorpay refund API failure.'
            );

        } catch (CalloutException e) {

            System.assert(
                e.getMessage().contains(
                    'Razorpay refund creation failed'
                )
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void createRefundFailsWithoutPaymentId() {

        RazorpayGatewayService.CreateRefundRequest request =
            new RazorpayGatewayService.CreateRefundRequest();

        request.amount = 10000;

        Test.startTest();

        try {

            RazorpayGatewayService.createRefund(request);

            System.assert(
                false,
                'Expected missing payment ID exception.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Razorpay Payment ID is required.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void createRefundFailsForInvalidAmount() {

        RazorpayGatewayService.CreateRefundRequest request =
            new RazorpayGatewayService.CreateRefundRequest();

        request.razorpayPaymentId =
            'pay_test_invalid';

        request.amount = 0;

        Test.startTest();

        try {

            RazorpayGatewayService.createRefund(request);

            System.assert(
                false,
                'Expected invalid refund amount exception.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Refund amount must be greater than zero.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}