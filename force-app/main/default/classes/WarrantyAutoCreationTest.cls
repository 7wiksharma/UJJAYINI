@IsTest
private class WarrantyAutoCreationTest {

    private static Asset createAsset(
        String serialNumber,
        Date purchaseDate
    ) {

        Account account = new Account(
            Name = 'Warranty Test Customer'
        );

        insert account;

        Asset asset = new Asset(
            Name = 'UJJAYINI Test Watch',
            AccountId = account.Id,
            Quantity = 1,
            Status = 'Purchased',
            SerialNumber = serialNumber,
            PurchaseDate = purchaseDate
        );

        insert asset;

        return asset;
    }


    @IsTest
    static void newAssetGetsTheDefaultWarranty() {

        Asset asset = createAsset(
            'UJJAYINI-TEST-1',
            Date.today()
        );

        Integer created =
            WarrantyService.createWarrantiesForAssets(
                new List<Asset>{ asset }
            );

        System.assertEquals(1, created);

        Warranty__c warranty = [
            SELECT Warranty_Status__c,
                   Warranty_Coverage_Type__c,
                   Warranty_Duration__c,
                   Warranty_Start_Date__c,
                   Warranty_End_Date__c
            FROM Warranty__c
            WHERE Asset__c = :asset.Id
        ];

        System.assertEquals('Active', warranty.Warranty_Status__c);
        System.assertEquals('Standard', warranty.Warranty_Coverage_Type__c);
        System.assertEquals(24, warranty.Warranty_Duration__c);
        System.assertEquals(Date.today(), warranty.Warranty_Start_Date__c);
        System.assertEquals(
            Date.today().addMonths(24),
            warranty.Warranty_End_Date__c
        );
    }


    @IsTest
    static void callingTwiceDoesNotDuplicateTheWarranty() {

        Asset asset = createAsset(
            'UJJAYINI-TEST-2',
            Date.today()
        );

        WarrantyService.createWarrantiesForAssets(
            new List<Asset>{ asset }
        );

        Integer secondRun =
            WarrantyService.createWarrantiesForAssets(
                new List<Asset>{ asset }
            );

        System.assertEquals(0, secondRun);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Warranty__c WHERE Asset__c = :asset.Id]
        );
    }


    @IsTest
    static void anOldPurchaseGetsAnExpiredWarranty() {

        Asset asset = createAsset(
            'UJJAYINI-TEST-3',
            Date.today().addMonths(-30)
        );

        WarrantyService.createWarrantiesForAssets(
            new List<Asset>{ asset }
        );

        Warranty__c warranty = [
            SELECT Warranty_Status__c
            FROM Warranty__c
            WHERE Asset__c = :asset.Id
        ];

        System.assertEquals('Expired', warranty.Warranty_Status__c);
    }


    @IsTest
    static void backfillOnlyCoversUjjayiniAssets() {

        Asset ujjayiniAsset = createAsset(
            'UJJAYINI-TEST-4',
            Date.today()
        );

        Asset otherAsset = createAsset(
            'SOMETHING-ELSE',
            Date.today()
        );

        Integer created =
            WarrantyService.createMissingWarranties();

        System.assertEquals(1, created);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Warranty__c WHERE Asset__c = :ujjayiniAsset.Id]
        );

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Warranty__c WHERE Asset__c = :otherAsset.Id]
        );
    }
}