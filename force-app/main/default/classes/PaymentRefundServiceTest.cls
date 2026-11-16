@IsTest
private class PaymentRefundServiceTest {

    private class RazorpayRefundSuccessMock
        implements HttpCalloutMock {

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
                2500000,
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
                '{"id":"rfnd_test_12345",' +
                '"entity":"refund",' +
                '"amount":2500000,' +
                '"currency":"INR",' +
                '"payment_id":"pay_test_12345",' +
                '"status":"processed"}'
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


    private static Account createAccount() {

        Account account = new Account(
            Name = 'UJJAYINI Refund Test Account'
        );

        insert account;

        return account;
    }


    private static Payment__c createPayment(
        Id orderId,
        String status,
        String gatewayPaymentId,
        String gatewayRefundId,
        Decimal amount
    ) {

        Payment__c payment =
            new Payment__c(
                Order__c = orderId,
                Amount__c = amount,
                Payment_Status__c = status
            );

        if (gatewayPaymentId != null) {
            payment.Gateway_Payment_ID__c =
                gatewayPaymentId;
        }

        if (gatewayRefundId != null) {
            payment.Gateway_Refund_ID__c =
                gatewayRefundId;
        }

        insert payment;

        return payment;
    }


    private static Order createOrder(
        Id accountId
    ) {

        Order orderRecord =
            new Order(
                AccountId = accountId,
                EffectiveDate = Date.today(),
                Status = 'Draft'
            );

        insert orderRecord;

        return orderRecord;
    }


    @IsTest
    static void createFullRefundSuccessfully() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Captured',
                'pay_test_12345',
                null,
                25000
            );

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayRefundSuccessMock()
        );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        request.amount =
            25000;

        Test.startTest();

        PaymentRefundService.RefundResult result =
            PaymentRefundService.createRefund(
                request
            );

        Test.stopTest();

        System.assertEquals(
            payment.Id,
            result.paymentId
        );

        System.assertEquals(
            'pay_test_12345',
            result.gatewayPaymentId
        );

        System.assertEquals(
            'rfnd_test_12345',
            result.gatewayRefundId
        );

        System.assertEquals(
            'processed',
            result.refundStatus
        );

        System.assertEquals(
            25000,
            result.refundAmount
        );

        System.assertEquals(
            'INR',
            result.currencyCode
        );

        Payment__c paymentAfter =
            [
                SELECT Id,
                       Payment_Status__c,
                       Gateway_Refund_ID__c,
                       Refunded_At__c
                FROM Payment__c
                WHERE Id = :payment.Id
            ];

        System.assertEquals(
            'Captured',
            paymentAfter.Payment_Status__c,
            'Refund API call must not prematurely mark payment as Refunded.'
        );

        System.assertEquals(
            null,
            paymentAfter.Gateway_Refund_ID__c,
            'Refund ID should be stored by the webhook confirmation flow.'
        );
    }


    @IsTest
    static void createPartialRefundSuccessfully() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Captured',
                'pay_test_54321',
                null,
                25000
            );

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayPartialRefundMock()
        );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        request.amount =
            10000;

        Test.startTest();

        PaymentRefundService.RefundResult result =
            PaymentRefundService.createRefund(
                request
            );

        Test.stopTest();

        System.assertEquals(
            'rfnd_test_54321',
            result.gatewayRefundId
        );

        System.assertEquals(
            10000,
            result.refundAmount
        );

        System.assertEquals(
            'processed',
            result.refundStatus
        );
    }


    @IsTest
    static void rejectPendingPayment() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Pending',
                'pay_test_pending',
                null,
                25000
            );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected pending payment to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Only captured payments can be refunded.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectFailedPayment() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Failed',
                'pay_test_failed',
                null,
                25000
            );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected failed payment to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Only captured payments can be refunded.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectMissingGatewayPaymentId() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Captured',
                null,
                null,
                25000
            );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected missing Gateway Payment ID to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Gateway Payment ID is required for refund.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectAlreadyRefundedPayment() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Captured',
                'pay_test_refunded',
                'rfnd_existing_12345',
                25000
            );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected already refunded payment to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Payment has already been refunded.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectRefundGreaterThanPayment() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Captured',
                'pay_test_amount',
                null,
                25000
            );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        request.amount =
            30000;

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected excessive refund amount to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Refund amount cannot exceed the payment amount.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectInvalidRefundAmount() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Captured',
                'pay_test_invalid_amount',
                null,
                25000
            );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        request.amount =
            0;

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected invalid refund amount to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Refund amount must be greater than zero.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectMissingRefundRequest() {

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                null
            );

            System.assert(
                false,
                'Expected missing refund request to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Refund request is required.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectMissingPaymentId() {

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected missing Payment Id to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Payment Id is required.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectRazorpayRefundFailure() {

        Account account =
            createAccount();

        Order orderRecord =
            createOrder(account.Id);

        Payment__c payment =
            createPayment(
                orderRecord.Id,
                'Captured',
                'pay_test_error',
                null,
                25000
            );

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayRefundErrorMock()
        );

        PaymentRefundService.RefundRequest request =
            new PaymentRefundService.RefundRequest();

        request.paymentId =
            payment.Id;

        request.amount =
            10000;

        Test.startTest();

        try {

            PaymentRefundService.createRefund(
                request
            );

            System.assert(
                false,
                'Expected Razorpay refund failure.'
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
}