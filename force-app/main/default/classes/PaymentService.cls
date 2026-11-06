public with sharing class PaymentService {

    public class PaymentRequest {
        public Id orderId;
        public Decimal amount;
        public String paymentMethod;
    }

    public class PaymentResult {
        public Id paymentId;
        public Id orderId;
        public Decimal amount;
        public String paymentStatus;
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

        Payment__c payment = new Payment__c(
            Order__c = orderRecord.Id,
            Amount__c = request.amount,
            Payment_Status__c = 'Pending'
        );

        if (request.paymentMethod != null) {
            payment.Payment_Method__c = request.paymentMethod;
        }

        insert payment;

        PaymentResult result = new PaymentResult();

        result.paymentId = payment.Id;
        result.orderId = payment.Order__c;
        result.amount = payment.Amount__c;
        result.paymentStatus = payment.Payment_Status__c;

        return result;
    }


    private static Boolean isValidPaymentMethod(String paymentMethod) {

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