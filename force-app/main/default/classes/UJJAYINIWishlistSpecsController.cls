/**
 * Returns the public catalog specifications of the given timepieces
 * for the Wishlist comparison.
 *
 * Read-only. Only active products. No prices, stock or customer data.
 */
public with sharing class UJJAYINIWishlistSpecsController {

    private static final Integer MAX_PRODUCTS = 50;

    public class Spec {
        @AuraEnabled public String productId;
        @AuraEnabled public String productCode;
        @AuraEnabled public String brand;
        @AuraEnabled public String modelNumber;
        @AuraEnabled public String caseMaterial;
        @AuraEnabled public String strapMaterial;
        @AuraEnabled public String movement;
        @AuraEnabled public String dialColor;
        @AuraEnabled public String waterResistance;
        @AuraEnabled public String edition;
        @AuraEnabled public String warranty;
    }

    @AuraEnabled
    public static List<Spec> getSpecs(List<Id> productIds) {

        List<Spec> results = new List<Spec>();

        if (productIds == null || productIds.isEmpty()) {
            return results;
        }

        if (productIds.size() > MAX_PRODUCTS) {
            AuraHandledException error = new AuraHandledException('Too many timepieces requested.');
            error.setMessage('Too many timepieces requested.');
            throw error;
        }

        for (Product2 product : [
            SELECT Id,
                   ProductCode,
                   Brand__c,
                   Model_Number__c,
                   Case_Material__c,
                   Strap_Material__c,
                   Movement_Type__c,
                   Dial_Color__c,
                   Water_Resistance__c,
                   Limited_Edition__c,
                   Edition_Size__c,
                   Warranty_Period__c
            FROM Product2
            WHERE Id IN :productIds
              AND IsActive = true
            WITH SYSTEM_MODE
        ]) {

            Spec spec = new Spec();

            spec.productId       = product.Id;
            spec.productCode     = product.ProductCode;
            spec.brand           = text(product.Brand__c);
            spec.modelNumber     = text(product.Model_Number__c);
            spec.caseMaterial    = text(product.Case_Material__c);
            spec.strapMaterial   = text(product.Strap_Material__c);
            spec.movement        = text(product.Movement_Type__c);
            spec.dialColor       = text(product.Dial_Color__c);
            spec.waterResistance = text(product.Water_Resistance__c);
            spec.edition         = editionLabel(product.Limited_Edition__c, product.Edition_Size__c);
            spec.warranty        = warrantyLabel(product.Warranty_Period__c);

            results.add(spec);
        }

        return results;
    }

    @TestVisible
    private static String text(Object value) {

        if (value == null) {
            return null;
        }

        String result = String.valueOf(value).trim();

        return String.isBlank(result) ? null : result;
    }

    @TestVisible
    private static String editionLabel(Boolean limited, Decimal size) {

        if (limited != true) {
            return 'Regular production';
        }

        if (size == null || size <= 0) {
            return 'Limited edition';
        }

        return 'Limited · ' + size.intValue() + (size.intValue() == 1 ? ' piece' : ' pieces');
    }

    @TestVisible
    private static String warrantyLabel(Decimal months) {

        if (months == null || months <= 0) {
            return null;
        }

        return months.intValue() + ' months';
    }
}