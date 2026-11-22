public with sharing class CollectorVaultService {

    /*
     * Used only by tests: lets a test choose the customer Account
     * without creating a real Experience Cloud user.
     */
    @TestVisible
    private static Id testAccountId;


    public class AssetResult {

        @AuraEnabled public Id assetId;
        @AuraEnabled public String name;
        @AuraEnabled public String productName;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productImageUrl;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal price;
        @AuraEnabled public String status;
        @AuraEnabled public Date purchaseDate;

        /*
         * Kept for compatibility, but never sent to the browser any
         * more: the internal fulfilment marker (UJJAYINI-<OrderId>)
         * must not be shown to customers.
         */
        @AuraEnabled public String serialNumber;

        // Customer-facing certificate number (stable per Asset)
        @AuraEnabled public String certificateNumber;

        // Timepiece details for the Vault
        @AuraEnabled public String collectionName;
        @AuraEnabled public String movement;
        @AuraEnabled public String caseMaterial;
        @AuraEnabled public String dialColor;
        @AuraEnabled public String modelNumber;
        @AuraEnabled public Boolean limitedEdition;
        @AuraEnabled public Integer editionSize;
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

        @AuraEnabled public String state;
        @AuraEnabled public Boolean paymentConfirmed;
        @AuraEnabled public Boolean assetReady;
    }


    // =========================================================
    // MY ASSETS
    // =========================================================

    @AuraEnabled(cacheable=true)
    public static List<AssetResult> getMyAssets() {

        List<AssetResult> results = new List<AssetResult>();

        Id accountId = getCurrentAccountId();

        if (accountId == null) {
            return results;
        }

        for (Asset asset : [
            SELECT Id,
                   Name,
                   Product2Id,
                   Product2.Name,
                   Product2.Product_Image_URL__c,
                   Product2.Collection__r.Name,
                   Product2.Movement_Type__c,
                   Product2.Case_Material__c,
                   Product2.Dial_Color__c,
                   Product2.Model_Number__c,
                   Product2.Limited_Edition__c,
                   Product2.Edition_Size__c,
                   Quantity,
                   Price,
                   Status,
                   PurchaseDate,
                   CreatedDate
            FROM Asset
            WHERE AccountId = :accountId
            AND Status != 'Obsolete'
            WITH SYSTEM_MODE
            ORDER BY PurchaseDate DESC, CreatedDate DESC
        ]) {

            AssetResult result = new AssetResult();

            result.assetId = asset.Id;
            result.name = asset.Name;
            result.productId = asset.Product2Id;
            result.quantity = asset.Quantity;
            result.price = asset.Price;
            result.status = asset.Status;
            result.purchaseDate = asset.PurchaseDate;
            result.certificateNumber = certificateNumber(asset);

            Product2 product = asset.Product2;

            if (product != null) {

                result.productName = product.Name;
                result.productImageUrl = product.Product_Image_URL__c;
                result.collectionName = product.Collection__r != null ? product.Collection__r.Name : null;
                result.movement = text(product.Movement_Type__c);
                result.caseMaterial = text(product.Case_Material__c);
                result.dialColor = text(product.Dial_Color__c);
                result.modelNumber = text(product.Model_Number__c);
                result.limitedEdition = product.Limited_Edition__c == true;
                result.editionSize = product.Edition_Size__c == null
                    ? null
                    : Integer.valueOf(product.Edition_Size__c);

            } else {

                result.productName = 'UJJAYINI Watch';
                result.limitedEdition = false;
            }

            results.add(result);
        }

        return results;
    }


    // =========================================================
    // CERTIFICATE NUMBER
    //
    // Stable for the life of the Asset and derived only from it,
    // so no new field is needed. It reveals no internal Id.
    //   UJ-COA-<year>-<8 hex characters>
    // =========================================================

    public static String certificateNumber(Asset asset) {

        Integer year = asset.PurchaseDate != null
            ? asset.PurchaseDate.year()
            : (asset.CreatedDate != null ? asset.CreatedDate.year() : Date.today().year());

        String digest = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf('UJJAYINI-COA-' + String.valueOf(asset.Id)))
        );

        return 'UJ-COA-' + year + '-' + digest.substring(0, 8).toUpperCase();
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
    public static PaymentVerificationResult verifyPayment(String paymentLinkId) {

        PaymentVerificationResult result = new PaymentVerificationResult();
        result.state = 'NOT_FOUND';
        result.paymentConfirmed = false;
        result.assetReady = false;

        Id accountId = getCurrentAccountId();

        if (accountId == null) {
            return result;
        }

        Payment__c payment = new PaymentLookup().findOwnedPayment(accountId, paymentLinkId);

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
        String fulfillmentMarker = 'UJJAYINI-' + String.valueOf(payment.Order__c);

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


    // =========================================================
    // HELPERS
    // =========================================================

    public static Id getCurrentAccountId() {

        if (Test.isRunningTest() && testAccountId != null) {
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

    private static String text(Object value) {

        if (value == null) {
            return null;
        }

        String result = String.valueOf(value).trim();

        return String.isBlank(result) ? null : result;
    }


    /*
     * Payment__c / Order records are created by the checkout and the
     * Razorpay webhook (a different user), so the customer may not
     * have record sharing on them. This lookup therefore runs
     * without sharing, but it ONLY returns a payment whose Order
     * belongs to the Account passed in (the logged-in customer's).
     */
    private without sharing class PaymentLookup {

        public Payment__c findOwnedPayment(Id accountId, String paymentLinkId) {

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

            return payments.isEmpty() ? null : payments[0];
        }
    }
}