public with sharing class PaymentRefundService {

    public class RefundRequest {
        public Id paymentId;
        public Decimal amount;
        public String receipt;
        public String notes;
    }

    public class RefundResult {
        public Id paymentId;
        public String gatewayPaymentId;
        public String gatewayRefundId;
        public String refundStatus;
        public Decimal refundAmount;
        public String currencyCode;
    }


    public static RefundResult createRefund(
        RefundRequest request
    ) {

        if (request == null) {
            throw new IllegalArgumentException(
                'Refund request is required.'
            );
        }

        if (request.paymentId == null) {
            throw new IllegalArgumentException(
                'Payment Id is required.'
            );
        }

        if (request.amount != null && request.amount <= 0) {
            throw new IllegalArgumentException(
                'Refund amount must be greater than zero.'
            );
        }

        Payment__c payment = [
            SELECT Id,
                   Order__c,
                   Amount__c,
                   Payment_Status__c,
                   Gateway_Payment_ID__c,
                   Gateway_Refund_ID__c
            FROM Payment__c
            WHERE Id = :request.paymentId
            FOR UPDATE
        ];

        if (payment.Payment_Status__c != 'Captured') {
            throw new IllegalArgumentException(
                'Only captured payments can be refunded.'
            );
        }

        if (String.isBlank(payment.Gateway_Payment_ID__c)) {
            throw new IllegalArgumentException(
                'Gateway Payment ID is required for refund.'
            );
        }

        if (!String.isBlank(payment.Gateway_Refund_ID__c)) {
            throw new IllegalArgumentException(
                'Payment has already been refunded.'
            );
        }

        if (request.amount != null &&
            request.amount > payment.Amount__c) {

            throw new IllegalArgumentException(
                'Refund amount cannot exceed the payment amount.'
            );
        }

        RazorpayGatewayService.CreateRefundRequest gatewayRequest =
            new RazorpayGatewayService.CreateRefundRequest();

        gatewayRequest.razorpayPaymentId =
            payment.Gateway_Payment_ID__c;

        gatewayRequest.amount =
            request.amount;

        gatewayRequest.receipt =
            request.receipt;

        gatewayRequest.notes =
            request.notes;

        RazorpayGatewayService.CreateRefundResult gatewayResult =
            RazorpayGatewayService.createRefund(
                gatewayRequest
            );

        RefundResult result =
            new RefundResult();

        result.paymentId =
            payment.Id;

        result.gatewayPaymentId =
            payment.Gateway_Payment_ID__c;

        result.gatewayRefundId =
            gatewayResult.razorpayRefundId;

        result.refundStatus =
            gatewayResult.status;

        result.refundAmount =
            gatewayResult.amount;

        result.currencyCode =
            gatewayResult.currencyCode;

        return result;
    }
}