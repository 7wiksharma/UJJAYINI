public without sharing class UJJAYINICustomerAccessService {

    /*
     * API names of the permission sets every customer needs.
     * Fill these from Step 1 (PermissionSet.Name).
     * Never add the admin-only permission sets here.
     */
       @TestVisible
    private static Set<String> CUSTOMER_PERMISSION_SETS = new Set<String>{
        'UJJAYINI_Product_Catalog_Access'
    };

    /*
     * Called after new users are inserted. Customer users get
     * their permission sets in a separate (future) transaction,
     * because registration also creates an Account and a Contact.
     */
    public static void grantAccess(List<User> users) {

        Set<Id> customerIds = new Set<Id>();

        for (User u : users) {
            if (u.ContactId != null && u.IsActive) {
                customerIds.add(u.Id);
            }
        }

        if (customerIds.isEmpty()) {
            return;
        }

        if (System.isFuture() || System.isBatch() || System.isQueueable()) {
            assign(customerIds);
        } else {
            assignLater(customerIds);
        }
    }


    @future
    private static void assignLater(Set<Id> userIds) {
        assign(userIds);
    }


    /*
     * Run once from Anonymous Apex to give access to customers
     * who already exist (for example NTR sharma).
     */
    public static void grantToAllCustomers() {

        Map<Id, User> customers = new Map<Id, User>([
            SELECT Id
            FROM User
            WHERE ContactId != null
            AND IsActive = true
        ]);

        assign(customers.keySet());
    }


    @TestVisible
    private static void assign(Set<Id> userIds) {

        if (userIds == null || userIds.isEmpty()) {
            return;
        }

        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN :CUSTOMER_PERMISSION_SETS
        ];

        if (permissionSets.isEmpty()) {
            System.debug(
                LoggingLevel.ERROR,
                'UJJAYINI: no customer permission sets found. Check the names.'
            );
            return;
        }

        Set<String> existing = new Set<String>();

        for (PermissionSetAssignment psa : [
            SELECT AssigneeId, PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :userIds
            AND PermissionSetId IN :permissionSets
        ]) {
            existing.add(psa.AssigneeId + ':' + psa.PermissionSetId);
        }

        List<PermissionSetAssignment> toInsert =
            new List<PermissionSetAssignment>();

        for (Id userId : userIds) {
            for (PermissionSet ps : permissionSets) {

                if (!existing.contains(userId + ':' + ps.Id)) {
                    toInsert.add(new PermissionSetAssignment(
                        AssigneeId = userId,
                        PermissionSetId = ps.Id
                    ));
                }
            }
        }

        if (toInsert.isEmpty()) {
            return;
        }

        // Partial success: one bad row must not block the others.
        for (Database.SaveResult result : Database.insert(toInsert, false)) {

            if (!result.isSuccess()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'UJJAYINI permission set assignment failed: ' +
                    result.getErrors()[0].getMessage()
                );
            }
        }
    }
}