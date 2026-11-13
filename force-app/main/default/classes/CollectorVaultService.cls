public with sharing class CollectorVaultService {

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
}