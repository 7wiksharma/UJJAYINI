@IsTest
private class UJJAYINICertificateControllerTest {

    @TestSetup
    static void setup() {

        Account owner = new Account(Name = 'Certificate Owner');
        Account stranger = new Account(Name = 'Someone Else');
        insert new List<Account>{ owner, stranger };

        insert new Contact(FirstName = 'Asha', LastName = 'Collector', AccountId = owner.Id);

        Product2 watch = new Product2(Name = 'Certificate Test Watch', ProductCode = 'UJ-CERT-01', IsActive = true);
        insert watch;

        insert new List<Asset>{
            new Asset(Name = 'Owned', AccountId = owner.Id, Product2Id = watch.Id, Quantity = 1, Status = 'Purchased', PurchaseDate = Date.newInstance(2026, 11, 21)),
            new Asset(Name = 'Not mine', AccountId = stranger.Id, Product2Id = watch.Id, Quantity = 1, Status = 'Purchased')
        };
    }

    private static Account accountNamed(String name) {
        return [SELECT Id FROM Account WHERE Name = :name LIMIT 1];
    }

    private static Asset assetNamed(String name) {
        return [SELECT Id FROM Asset WHERE Name = :name LIMIT 1];
    }

    @IsTest
    static void ownerGetsCertificate() {

        CollectorVaultService.testAccountId = accountNamed('Certificate Owner').Id;
        Id assetId = assetNamed('Owned').Id;

        Test.startTest();
        UJJAYINICertificateController.CertificateFile file = UJJAYINICertificateController.getMyCertificate(assetId);
        Test.stopTest();

        System.assert(file.certificateNumber.startsWith('UJ-COA-2026-'), file.certificateNumber);
        System.assertEquals(20, file.certificateNumber.length());
        System.assert(file.fileName.endsWith('.pdf'));
        System.assert(String.isNotBlank(file.base64));

        // Stable: same number every time.
        System.assertEquals(file.certificateNumber, UJJAYINICertificateController.getMyCertificate(assetId).certificateNumber);
    }

    @IsTest
    static void htmlNamesTheOwnerAndTimepiece() {

        CollectorVaultService.testAccountId = accountNamed('Certificate Owner').Id;

        Asset asset = UJJAYINICertificateController.loadOwnedAsset(assetNamed('Owned').Id);
        String html = UJJAYINICertificateController.buildHtml(asset);

        System.assert(html.contains('Asha Collector'));
        System.assert(html.contains('Certificate Test Watch'));
        System.assert(html.contains('21 November 2026'));
        System.assert(!html.contains(String.valueOf(asset.Id)), 'Internal Id must not appear');
    }

    @IsTest
    static void strangerCannotDownload() {

        CollectorVaultService.testAccountId = accountNamed('Certificate Owner').Id;

        Boolean blocked = false;

        try {
            UJJAYINICertificateController.getMyCertificate(assetNamed('Not mine').Id);
        } catch (AuraHandledException e) {
            blocked = true;
        }

        System.assert(blocked, 'Another customer\'s asset must be refused');
    }

    @IsTest
    static void vaultListsCertificateNumberNotSerial() {

        CollectorVaultService.testAccountId = accountNamed('Certificate Owner').Id;

        List<CollectorVaultService.AssetResult> assets = CollectorVaultService.getMyAssets();

        System.assertEquals(1, assets.size());
        System.assert(assets[0].certificateNumber.startsWith('UJ-COA-'));
        System.assertEquals(null, assets[0].serialNumber);
        System.assertEquals('Certificate Test Watch', assets[0].productName);
    }

    @IsTest
    static void formatsDates() {
        System.assertEquals('5 March 2027', UJJAYINICertificateController.formatDate(Date.newInstance(2027, 3, 5)));
        System.assertEquals(null, UJJAYINICertificateController.formatDate(null));
    }
}