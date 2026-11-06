public with sharing class PaymentService {

    public class PaymentRequest {
        public Id orderId;
        public Decimal amount;
        public String paymentMethod;
        public String receipt;
    }

    public class PaymentResult {
        public Id paymentId;
        public Id orderId;
        public Decimal amount;
        public String paymentStatus;
        public String gatewayOrderId;
    }

    public static PaymentResult createPayment(PaymentRequest request) {

        if (request == null) {
            throw new IllegalArgumentException(
                'Payment request is required.'
            );
        }

        if (request.orderId == null) {
            throw new IllegalArgumentException(
                'Order Id is required.'
            );
        }

        if (request.amount == null || request.amount <= 0) {
            throw new IllegalArgumentException(
                'Payment amount must be greater than zero.'
            );
        }

        if (request.paymentMethod != null &&
            !isValidPaymentMethod(request.paymentMethod)) {

            throw new IllegalArgumentException(
                'Invalid payment method.'
            );
        }

        Order orderRecord = [
            SELECT Id
            FROM Order
            WHERE Id = :request.orderId
            LIMIT 1
        ];

        /*
         * Create the Razorpay order first.
         */
        RazorpayGatewayService.CreateOrderRequest razorpayRequest =
            new RazorpayGatewayService.CreateOrderRequest();

        razorpayRequest.amount = request.amount;
        razorpayRequest.currencyCode = 'INR';

        if (!String.isBlank(request.receipt)) {
            razorpayRequest.receipt = request.receipt;
        } else {
            razorpayRequest.receipt =
                'UJ-' + String.valueOf(orderRecord.Id);
        }

        RazorpayGatewayService.CreateOrderResult razorpayResult =
            RazorpayGatewayService.createOrder(
                razorpayRequest
            );

        /*
         * Store the Razorpay order information
         * in the Salesforce Payment record.
         */
        Payment__c payment = new Payment__c(
            Order__c = orderRecord.Id,
            Amount__c = request.amount,
            Payment_Status__c = 'Pending',
            Gateway_Order_ID__c =
                razorpayResult.razorpayOrderId
        );

        if (request.paymentMethod != null) {
            payment.Payment_Method__c =
                request.paymentMethod;
        }

        insert payment;

        PaymentResult result =
            new PaymentResult();

        result.paymentId =
            payment.Id;

        result.orderId =
            payment.Order__c;

        result.amount =
            payment.Amount__c;

        result.paymentStatus =
            payment.Payment_Status__c;

        result.gatewayOrderId =
            payment.Gateway_Order_ID__c;

        return result;
    }


    private static Boolean isValidPaymentMethod(
        String paymentMethod
    ) {

        Set<String> validMethods = new Set<String>{
            'UPI',
            'Credit Card',
            'Debit Card',
            'Net Banking',
            'EMI',
            'Wallet',
            'Other'
        };

        return validMethods.contains(paymentMethod);
    }
}