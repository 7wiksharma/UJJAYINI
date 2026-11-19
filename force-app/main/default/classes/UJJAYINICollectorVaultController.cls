public with sharing class UJJAYINICollectorVaultController {

    @AuraEnabled(cacheable=true)
    public static List<CollectorVaultService.AssetResult> getMyAssets() {

        try {

            return CollectorVaultService.getMyAssets();

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }


    @AuraEnabled
    public static CollectorVaultService.PaymentVerificationResult verifyPayment(
        String paymentLinkId
    ) {

        try {

            return CollectorVaultService.verifyPayment(
                paymentLinkId
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}