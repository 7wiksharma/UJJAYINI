/**
 * Certificate of Authenticity & Ownership for a timepiece in the
 * customer's Collector Vault.
 *
 * The PDF is built on the server and only for an Asset that belongs
 * to the logged-in customer's Account. Data is read in SYSTEM_MODE
 * because the Asset, Product and Warranty were created by other users
 * (webhook / fulfilment); the ownership check below is what protects it.
 */
public with sharing class UJJAYINICertificateController {

    private static final String NOT_AVAILABLE =
        'This certificate is not available. Please refresh your Vault and try again.';

    public class CertificateFile {
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64;
        @AuraEnabled public String certificateNumber;
    }


    @AuraEnabled
    public static CertificateFile getMyCertificate(Id assetId) {

        try {

            Asset asset = loadOwnedAsset(assetId);

            CertificateFile file = new CertificateFile();
            file.certificateNumber = CollectorVaultService.certificateNumber(asset);
            file.fileName = 'UJJAYINI-Certificate-' + file.certificateNumber + '.pdf';
            file.base64 = EncodingUtil.base64Encode(Blob.toPdf(buildHtml(asset)));

            return file;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw friendly();
        }
    }


    // =========================================================
    // DATA
    // =========================================================

    @TestVisible
    private static Asset loadOwnedAsset(Id assetId) {

        Id accountId = CollectorVaultService.getCurrentAccountId();

        if (assetId == null || accountId == null) {
            throw friendly();
        }

        List<Asset> assets = [
            SELECT Id,
                   Name,
                   AccountId,
                   ContactId,
                   Status,
                   PurchaseDate,
                   CreatedDate,
                   Product2.Name,
                   Product2.ProductCode,
                   Product2.Collection__r.Name,
                   Product2.Model_Number__c,
                   Product2.Movement_Type__c,
                   Product2.Case_Material__c,
                   Product2.Dial_Color__c,
                   Product2.Limited_Edition__c,
                   Product2.Edition_Size__c
            FROM Asset
            WHERE Id = :assetId
            AND AccountId = :accountId
            AND Status != 'Obsolete'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (assets.isEmpty()) {
            throw friendly();
        }

        return assets[0];
    }

    private static String ownerName(Asset asset) {

        List<Contact> contacts;

        if (asset.ContactId != null) {
            contacts = [SELECT Name FROM Contact WHERE Id = :asset.ContactId WITH SYSTEM_MODE LIMIT 1];
            if (!contacts.isEmpty()) {
                return contacts[0].Name;
            }
        }

        contacts = [
            SELECT Name
            FROM Contact
            WHERE AccountId = :asset.AccountId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        return contacts.isEmpty() ? 'The Collector' : contacts[0].Name;
    }

    private static Warranty__c warrantyFor(Id assetId) {

        List<Warranty__c> warranties = [
            SELECT Warranty_Status__c,
                   Warranty_Coverage_Type__c,
                   Warranty_End_Date__c
            FROM Warranty__c
            WHERE Asset__c = :assetId
            WITH SYSTEM_MODE
            ORDER BY Warranty_End_Date__c DESC NULLS LAST
            LIMIT 1
        ];

        return warranties.isEmpty() ? null : warranties[0];
    }


    // =========================================================
    // PDF (Blob.toPdf supports CSS 2.1: tables, borders, no flexbox)
    // =========================================================

    @TestVisible
    private static String buildHtml(Asset asset) {

        Product2 product = asset.Product2;
        Warranty__c warranty = warrantyFor(asset.Id);

        String timepiece = product != null ? product.Name : 'UJJAYINI Timepiece';
        String collection = product != null && product.Collection__r != null ? product.Collection__r.Name : null;

        String edition = 'Regular production';
        if (product != null && product.Limited_Edition__c == true) {
            edition = product.Edition_Size__c != null
                ? 'Limited edition of ' + Integer.valueOf(product.Edition_Size__c) + ' pieces'
                : 'Limited edition';
        }

        Date acquired = asset.PurchaseDate != null
            ? asset.PurchaseDate
            : (asset.CreatedDate != null ? asset.CreatedDate.date() : Date.today());

        String warrantyLine = null;
        if (warranty != null && warranty.Warranty_Status__c != 'Voided') {
            warrantyLine = (warranty.Warranty_Coverage_Type__c != null ? warranty.Warranty_Coverage_Type__c + ' coverage' : 'Coverage')
                + (warranty.Warranty_End_Date__c != null ? ' until ' + formatDate(warranty.Warranty_End_Date__c) : '');
        }

        List<String> h = new List<String>();

        h.add('<html><head><style>');
        h.add('@page { size: A4 landscape; margin: 0; }');
        h.add('body { margin: 0; font-family: Helvetica, Arial, sans-serif; color: #1d1a15; background: #f7f1e3; }');
        h.add('.sheet { margin: 12mm; border: 3px double #b08a3a; padding: 4mm; }');
        h.add('.inner { border: 1px solid #d8c18a; padding: 10mm 16mm 9mm; text-align: center; }');
        h.add('.brand { font-family: "Times New Roman", serif; font-size: 22pt; letter-spacing: 10pt; color: #1d1a15; }');
        h.add('.tag { font-size: 6.5pt; letter-spacing: 4pt; color: #a8822f; margin-top: 2mm; }');
        h.add('.mono { display: inline-block; width: 14mm; height: 14mm; line-height: 14mm; border: 1px solid #b08a3a; font-family: "Times New Roman", serif; font-size: 20pt; color: #a8822f; margin-bottom: 3mm; }');
        h.add('.title { font-family: "Times New Roman", serif; font-size: 30pt; margin-top: 5mm; letter-spacing: 1pt; }');
        h.add('.subtitle { font-family: "Times New Roman", serif; font-style: italic; font-size: 15pt; color: #a8822f; }');
        h.add('.lede { font-size: 9pt; color: #5c5243; margin: 5mm auto 2mm; width: 70%; line-height: 14pt; }');
        h.add('.owner { font-family: "Times New Roman", serif; font-style: italic; font-size: 26pt; margin: 2mm 0 4mm; }');
        h.add('.rule { border-top: 1px solid #c9a24d; width: 40%; margin: 0 auto 5mm; }');
        h.add('table.specs { width: 82%; margin: 0 auto; border-collapse: collapse; }');
        h.add('table.specs td { padding: 2.2mm 3mm; border-bottom: 1px solid #e3d5b3; font-size: 9pt; text-align: left; }');
        h.add('td.label { font-size: 6.5pt; letter-spacing: 2.5pt; color: #a8822f; width: 22%; }');
        h.add('td.value { font-family: "Times New Roman", serif; font-size: 11.5pt; width: 28%; }');
        h.add('table.foot { width: 100%; margin-top: 7mm; border-collapse: collapse; }');
        h.add('table.foot td { font-size: 7pt; color: #5c5243; vertical-align: bottom; }');
        h.add('.seal { border: 1px solid #b08a3a; padding: 3mm 5mm; display: inline-block; letter-spacing: 2.5pt; font-size: 7pt; color: #a8822f; }');
        h.add('.number { font-family: "Courier New", monospace; font-size: 10pt; color: #1d1a15; letter-spacing: 1pt; }');
        h.add('</style></head><body>');

        h.add('<div class="sheet"><div class="inner">');

        h.add('<div class="mono">U</div>');
        h.add('<div class="brand">UJJAYINI</div>');
        h.add('<div class="tag">THE BEGINNING OF YOUR TIME</div>');

        h.add('<div class="title">Certificate of Authenticity</div>');
        h.add('<div class="subtitle">and Ownership</div>');

        h.add('<div class="lede">This is to certify that the timepiece described below is an authentic creation of the House of UJJAYINI, and that it is held in the private collection of</div>');
        h.add('<div class="owner">' + esc(ownerName(asset)) + '</div>');
        h.add('<div class="rule"></div>');

        h.add('<table class="specs">');
        h.add(row('TIMEPIECE', timepiece, 'COLLECTION', collection));
        h.add(row('REFERENCE', product != null ? product.ProductCode : null, 'MODEL', product != null ? product.Model_Number__c : null));
        h.add(row('MOVEMENT', product != null ? String.valueOf(product.Movement_Type__c) : null, 'CASE', product != null ? String.valueOf(product.Case_Material__c) : null));
        h.add(row('DIAL', product != null ? String.valueOf(product.Dial_Color__c) : null, 'EDITION', edition));
        h.add(row('ACQUIRED ON', formatDate(acquired), 'WARRANTY', warrantyLine));
        h.add('</table>');

        h.add('<table class="foot"><tr>');
        h.add('<td style="text-align: left; width: 40%;">CERTIFICATE NO.<br/><span class="number">' + esc(CollectorVaultService.certificateNumber(asset)) + '</span></td>');
        h.add('<td style="text-align: center; width: 20%;"><span class="seal">AUTHENTICATED<br/>BY THE HOUSE</span></td>');
        h.add('<td style="text-align: right; width: 40%;">Time is not simply measured. It is remembered.<br/>Computer-generated certificate. No signature required.</td>');
        h.add('</tr></table>');

        h.add('</div></div></body></html>');

        return String.join(h, '');
    }

    private static String row(String labelA, String valueA, String labelB, String valueB) {
        return '<tr>'
            + '<td class="label">' + labelA + '</td><td class="value">' + esc(blankDash(valueA)) + '</td>'
            + '<td class="label">' + labelB + '</td><td class="value">' + esc(blankDash(valueB)) + '</td>'
            + '</tr>';
    }

    private static String blankDash(String value) {
        return String.isBlank(value) || value == 'null' ? '—' : value;
    }

    private static String esc(String value) {
        return value == null ? '' : value.escapeHtml4();
    }

    @TestVisible
    private static String formatDate(Date value) {

        if (value == null) {
            return null;
        }

        List<String> months = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };

        return value.day() + ' ' + months[value.month() - 1] + ' ' + value.year();
    }

    private static AuraHandledException friendly() {
        AuraHandledException error = new AuraHandledException(NOT_AVAILABLE);
        error.setMessage(NOT_AVAILABLE);
        return error;
    }
}