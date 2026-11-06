@IsTest
private class PaymentServiceTest {

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

            Map<String, Object> requestBody =
                (Map<String, Object>) JSON.deserializeUntyped(
                    request.getBody()
                );

            System.assertEquals(
                5000000,
                requestBody.get('amount')
            );

            System.assertEquals(
                'INR',
                requestBody.get('currency')
            );

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setBody(
                '{"id":"order_test_payment_123",' +
                '"entity":"order",' +
                '"amount":5000000,' +
                '"amount_paid":0,' +
                '"amount_due":5000000,' +
                '"currency":"INR",' +
                '"receipt":"UJ-TEST-PAYMENT",' +
                '"status":"created"}'
            );

            return response;
        }
    }


    @IsTest
    static void createPaymentSuccessfully() {

        Account account = new Account(
            Name = 'UJJAYINI Payment Test Account'
        );
        insert account;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert orderRecord;

        PaymentService.PaymentRequest request =
            new PaymentService.PaymentRequest();

        request.orderId = orderRecord.Id;
        request.amount = 50000;
        request.paymentMethod = 'Credit Card';
        request.receipt = 'UJ-TEST-PAYMENT';

        Test.setMock(
            HttpCalloutMock.class,
            new RazorpayOrderMock()
        );

        Test.startTest();

        PaymentService.PaymentResult result =
            PaymentService.createPayment(request);

        Test.stopTest();

        Payment__c payment = [
            SELECT Order__c,
                   Amount__c,
                   Payment_Status__c,
                   Payment_Method__c,
                   Gateway_Order_ID__c
            FROM Payment__c
            WHERE Id = :result.paymentId
        ];

        System.assertNotEquals(
            null,
            result.paymentId,
            'Payment should be created.'
        );

        System.assertEquals(
            orderRecord.Id,
            result.orderId
        );

        System.assertEquals(
            50000,
            result.amount
        );

        System.assertEquals(
            'Pending',
            result.paymentStatus
        );

        System.assertEquals(
            'order_test_payment_123',
            result.gatewayOrderId
        );

        System.assertEquals(
            orderRecord.Id,
            payment.Order__c
        );

        System.assertEquals(
            50000,
            payment.Amount__c
        );

        System.assertEquals(
            'Pending',
            payment.Payment_Status__c
        );

        System.assertEquals(
            'Credit Card',
            payment.Payment_Method__c
        );

        System.assertEquals(
            'order_test_payment_123',
            payment.Gateway_Order_ID__c
        );
    }


    @IsTest
    static void rejectsInvalidPaymentAmount() {

        Account account = new Account(
            Name = 'UJJAYINI Invalid Payment Account'
        );
        insert account;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert orderRecord;

        PaymentService.PaymentRequest request =
            new PaymentService.PaymentRequest();

        request.orderId = orderRecord.Id;
        request.amount = 0;
        request.paymentMethod = 'UPI';

        Test.startTest();

        try {

            PaymentService.createPayment(request);

            System.assert(
                false,
                'Expected invalid payment amount to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Payment amount must be greater than zero.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void rejectsInvalidPaymentMethod() {

        Account account = new Account(
            Name = 'UJJAYINI Invalid Method Account'
        );
        insert account;

        Order orderRecord = new Order(
            AccountId = account.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert orderRecord;

        PaymentService.PaymentRequest request =
            new PaymentService.PaymentRequest();

        request.orderId = orderRecord.Id;
        request.amount = 25000;
        request.paymentMethod = 'Razorpay';

        Test.startTest();

        try {

            PaymentService.createPayment(request);

            System.assert(
                false,
                'Expected invalid payment method to be rejected.'
            );

        } catch (IllegalArgumentException e) {

            System.assertEquals(
                'Invalid payment method.',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}