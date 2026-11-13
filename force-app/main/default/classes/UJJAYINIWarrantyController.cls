public with sharing class UJJAYINIWarrantyController {

    @AuraEnabled(cacheable=true)
    public static List<WarrantyService.WarrantyResult> getMyWarranties() {

        try {

            return WarrantyService.getMyWarranties();

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}