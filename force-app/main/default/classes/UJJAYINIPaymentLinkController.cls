public with sharing class UJJAYINIPaymentLinkController {

    public class PaymentLinkResponse {

        @AuraEnabled
        public Id orderId;

        @AuraEnabled
        public Id paymentId;

        @AuraEnabled
        public String paymentLinkId;

        @AuraEnabled
        public String paymentUrl;

        @AuraEnabled
        public Decimal amount;

        @AuraEnabled
        public String status;
    }

    @AuraEnabled
    public static PaymentLinkResponse createPaymentLink(Id orderId) {

        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        RazorpayPaymentLinkService.PaymentLinkRequest request =
            new RazorpayPaymentLinkService.PaymentLinkRequest();

        request.orderId = orderId;

        try {

            RazorpayPaymentLinkService.PaymentLinkResult result =
                RazorpayPaymentLinkService.createPaymentLink(request);

            PaymentLinkResponse response =
                new PaymentLinkResponse();

            response.orderId = result.orderId;
            response.paymentId = result.paymentId;
            response.paymentLinkId = result.paymentLinkId;
            response.paymentUrl = result.paymentUrl;
            response.amount = result.amount;
            response.status = result.status;

            return response;

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}