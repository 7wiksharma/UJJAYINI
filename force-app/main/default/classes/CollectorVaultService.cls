public with sharing class CollectorVaultService {

    /*
     * Used only by tests: lets a test choose the customer Account
     * without creating a real Experience Cloud user.
     */
    @TestVisible
    private static Id testAccountId;


    public class AssetResult {

        @AuraEnabled
        public Id assetId;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productImageUrl;

        @AuraEnabled
        public Decimal quantity;

        @AuraEnabled
        public Decimal price;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String serialNumber;

        @AuraEnabled
        public Date purchaseDate;
    }


    /*
     * Result of verifying a payment after Razorpay redirects the
     * customer back. Only status flags are returned. No amounts,
     * gateway identifiers or other payment details.
     *
     * state:
     *   NOT_FOUND         no payment of THIS customer matches
     *   PENDING           payment exists but is not captured yet
     *   PAYMENT_CONFIRMED payment captured, Asset not created yet
     *   ASSET_READY       payment captured and Asset exists
     */
    public class PaymentVerificationResult {

        @AuraEnabled
        public String state;

        @AuraEnabled
        public Boolean paymentConfirmed;

        @AuraEnabled
        public Boolean assetReady;
    }


    @AuraEnabled(cacheable=true)
    public static List<AssetResult> getMyAssets() {

        User currentUser = [
            SELECT Id,
                   ContactId,
                   Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];


        if (
            currentUser.ContactId == null ||
            currentUser.Contact.AccountId == null
        ) {
            return new List<AssetResult>();
        }


        List<Asset> assets = [
            SELECT Id,
                   Name,
                   Product2Id,
                   Product2.Name,
                   Product2.Product_Image_URL__c,
                   Quantity,
                   Price,
                   Status,
                   SerialNumber,
                   PurchaseDate
            FROM Asset
            WHERE AccountId = :currentUser.Contact.AccountId
            WITH SYSTEM_MODE
            ORDER BY PurchaseDate DESC, CreatedDate DESC
        ];


        List<AssetResult> results =
            new List<AssetResult>();


        for (Asset asset : assets) {

            AssetResult result =
                new AssetResult();


            result.assetId =
                asset.Id;


            result.name =
                asset.Name;


            result.productId =
                asset.Product2Id;


            result.productName =
                asset.Product2 != null
                    ? asset.Product2.Name
                    : 'UJJAYINI Watch';


            result.productImageUrl =
                asset.Product2 != null
                    ? asset.Product2.Product_Image_URL__c
                    : null;


            result.quantity =
                asset.Quantity;


            result.price =
                asset.Price;


            result.status =
                asset.Status;


            result.serialNumber =
                asset.SerialNumber;


            result.purchaseDate =
                asset.PurchaseDate;


            results.add(result);
        }


        return results;
    }


    // =========================================================
    // VERIFY PAYMENT -> ASSET (after Razorpay redirects back)
    //
    // The URL parameters are only a trigger. This method decides,
    // from Salesforce data, whether the payment is captured and the
    // Asset exists, and it only ever looks at payments whose Order
    // belongs to the logged-in customer's Account.
    // =========================================================

    @AuraEnabled
    public static PaymentVerificationResult verifyPayment(
        String paymentLinkId
    ) {

        PaymentVerificationResult result =
            new PaymentVerificationResult();

        result.state = 'NOT_FOUND';
        result.paymentConfirmed = false;
        result.assetReady = false;

        Id accountId =
            getCurrentAccountId();

        if (accountId == null) {
            return result;
        }

        Payment__c payment =
            new PaymentLookup().findOwnedPayment(
                accountId,
                paymentLinkId
            );

        if (payment == null) {
            return result;
        }

        if (payment.Payment_Status__c != 'Captured') {

            result.state = 'PENDING';

            return result;
        }

        result.paymentConfirmed = true;
        result.state = 'PAYMENT_CONFIRMED';

        /*
         * AssetFulfillmentService marks every Asset of an Order
         * with the serial marker UJJAYINI-<OrderId>.
         */
        String fulfillmentMarker =
            'UJJAYINI-' + String.valueOf(payment.Order__c);

        Integer assetCount = [
            SELECT COUNT()
            FROM Asset
            WHERE AccountId = :accountId
            AND SerialNumber = :fulfillmentMarker
            WITH SYSTEM_MODE
        ];

        if (assetCount > 0) {

            result.assetReady = true;
            result.state = 'ASSET_READY';
        }

        return result;
    }


    private static Id getCurrentAccountId() {

        if (
            Test.isRunningTest() &&
            testAccountId != null
        ) {
            return testAccountId;
        }

        User currentUser = [
            SELECT Id,
                   ContactId,
                   Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (currentUser.ContactId == null) {
            return null;
        }

        return currentUser.Contact.AccountId;
    }


    /*
     * Payment__c / Order records are created by the checkout and the
     * Razorpay webhook (a different user), so the customer may not
     * have record sharing on them. This lookup therefore runs
     * without sharing, but it ONLY returns a payment whose Order
     * belongs to the Account passed in (the logged-in customer's).
     */
    private without sharing class PaymentLookup {

        public Payment__c findOwnedPayment(
            Id accountId,
            String paymentLinkId
        ) {

            List<Payment__c> payments;

            if (String.isNotBlank(paymentLinkId)) {

                payments = [
                    SELECT Id,
                           Order__c,
                           Payment_Status__c
                    FROM Payment__c
                    WHERE Gateway_Order_ID__c = :paymentLinkId
                    AND Order__c IN (
                        SELECT Id
                        FROM Order
                        WHERE AccountId = :accountId
                    )
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

            } else {

                payments = [
                    SELECT Id,
                           Order__c,
                           Payment_Status__c
                    FROM Payment__c
                    WHERE Order__c IN (
                        SELECT Id
                        FROM Order
                        WHERE AccountId = :accountId
                    )
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
            }

            return payments.isEmpty()
                ? null
                : payments[0];
        }
    }
}