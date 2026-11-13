public with sharing class UJJAYINICollectorVaultController {

    @AuraEnabled(cacheable=true)
    public static List<CollectorVaultService.AssetResult> getMyAssets() {

        try {

            return CollectorVaultService.getMyAssets();

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}