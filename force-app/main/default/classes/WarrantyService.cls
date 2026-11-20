public without sharing class WarrantyService {

    /*
     * Default warranty given to every new UJJAYINI timepiece.
     * Change these two values to change the warranty policy.
     */
    @TestVisible
    private static final String DEFAULT_COVERAGE_TYPE = 'Standard';

    @TestVisible
    private static final Integer DEFAULT_DURATION_MONTHS = 24;


    public class WarrantyResult {

        @AuraEnabled
        public Id warrantyId;

        @AuraEnabled
        public Id assetId;

        @AuraEnabled
        public String assetName;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String coverageType;

        @AuraEnabled
        public Integer durationMonths;

        @AuraEnabled
        public Date startDate;

        @AuraEnabled
        public Date endDate;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String notes;
    }


    public static List<WarrantyResult> getMyWarranties() {

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
            return new List<WarrantyResult>();
        }


        List<Warranty__c> warranties = [
            SELECT Id,
                   Asset__c,
                   Asset__r.Name,
                   Asset__r.Product2Id,
                   Asset__r.Product2.Name,
                   Warranty_Coverage_Type__c,
                   Warranty_Duration__c,
                   Warranty_Start_Date__c,
                   Warranty_End_Date__c,
                   Warranty_Status__c,
                   Warranty_Notes__c
            FROM Warranty__c
            WHERE Asset__r.AccountId = :currentUser.Contact.AccountId
            WITH SYSTEM_MODE
            ORDER BY Warranty_Start_Date__c DESC, CreatedDate DESC
        ];


        List<WarrantyResult> results =
            new List<WarrantyResult>();


        for (Warranty__c warranty : warranties) {

            WarrantyResult result =
                new WarrantyResult();

            result.warrantyId =
                warranty.Id;

            result.assetId =
                warranty.Asset__c;

            result.assetName =
                warranty.Asset__r != null
                    ? warranty.Asset__r.Name
                    : null;

            result.productName =
                warranty.Asset__r != null &&
                warranty.Asset__r.Product2 != null
                    ? warranty.Asset__r.Product2.Name
                    : 'UJJAYINI Watch';

            result.coverageType =
                warranty.Warranty_Coverage_Type__c;

            result.durationMonths =
                warranty.Warranty_Duration__c == null
                    ? null
                    : Integer.valueOf(
                        warranty.Warranty_Duration__c
                    );

            result.startDate =
                warranty.Warranty_Start_Date__c;

            result.endDate =
                warranty.Warranty_End_Date__c;

            result.status =
                warranty.Warranty_Status__c;

            result.notes =
                warranty.Warranty_Notes__c;

            results.add(result);
        }


        return results;
    }


    // =========================================================
    // AUTOMATIC WARRANTY FOR NEW ASSETS
    //
    // Skips every Asset that already has a Warranty, so it is safe
    // to call repeatedly (webhook retries, backfill, etc).
    // Warranty__c.Name is an Auto Number, so it is never set here.
    // Returns the number of warranties created.
    // =========================================================

    public static Integer createWarrantiesForAssets(
        List<Asset> assets
    ) {

        if (assets == null || assets.isEmpty()) {
            return 0;
        }

        Set<Id> assetIds = new Set<Id>();

        for (Asset asset : assets) {
            if (asset.Id != null) {
                assetIds.add(asset.Id);
            }
        }

        if (assetIds.isEmpty()) {
            return 0;
        }

        Set<Id> alreadyCovered = new Set<Id>();

        for (Warranty__c existing : [
            SELECT Asset__c
            FROM Warranty__c
            WHERE Asset__c IN :assetIds
            WITH SYSTEM_MODE
        ]) {
            alreadyCovered.add(existing.Asset__c);
        }

        List<Warranty__c> warranties =
            new List<Warranty__c>();

        for (Asset asset : assets) {

            if (
                asset.Id == null ||
                alreadyCovered.contains(asset.Id)
            ) {
                continue;
            }

            Date startDate =
                asset.PurchaseDate != null
                    ? asset.PurchaseDate
                    : Date.today();

            Date endDate =
                startDate.addMonths(
                    DEFAULT_DURATION_MONTHS
                );

            warranties.add(
                new Warranty__c(
                    Asset__c = asset.Id,
                    Warranty_Coverage_Type__c =
                        DEFAULT_COVERAGE_TYPE,
                    Warranty_Duration__c =
                        DEFAULT_DURATION_MONTHS,
                    Warranty_Start_Date__c = startDate,
                    Warranty_End_Date__c = endDate,
                    Warranty_Status__c =
                        endDate >= Date.today()
                            ? 'Active'
                            : 'Expired'
                )
            );
        }

        if (warranties.isEmpty()) {
            return 0;
        }

        /*
         * allOrNone = false: a warranty problem must never block
         * payment fulfillment. Failures are logged and can be
         * repaired later with createMissingWarranties().
         */
        List<Database.SaveResult> saveResults =
            Database.insert(
                warranties,
                false,
                AccessLevel.SYSTEM_MODE
            );

        Integer created = 0;

        for (Database.SaveResult saveResult : saveResults) {

            if (saveResult.isSuccess()) {

                created++;

            } else {

                System.debug(
                    LoggingLevel.ERROR,
                    'UJJAYINI warranty creation failed: ' +
                    saveResult.getErrors()[0].getMessage()
                );
            }
        }

        return created;
    }


    // =========================================================
    // BACKFILL
    //
    // Creates the default warranty for UJJAYINI Assets that do not
    // have one yet (up to 200 per run).
    // =========================================================

    public static Integer createMissingWarranties() {

        List<Asset> assets = [
            SELECT Id,
                   Name,
                   PurchaseDate
            FROM Asset
            WHERE SerialNumber LIKE 'UJJAYINI-%'
            AND Id NOT IN (
                SELECT Asset__c
                FROM Warranty__c
                WHERE Asset__c != null
            )
            WITH SYSTEM_MODE
            LIMIT 200
        ];

        return createWarrantiesForAssets(assets);
    }
}