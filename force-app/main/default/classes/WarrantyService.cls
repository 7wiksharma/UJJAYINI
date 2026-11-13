public without sharing class WarrantyService {

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
}