@IsTest
private class UJJAYINICustomerAccessServiceTest {

    @IsTest
    static void permissionSetsAreAssignedOnce() {

        PermissionSet ps = new PermissionSet(
            Name = 'UJJAYINI_Test_Customer_Access',
            Label = 'UJJAYINI Test Customer Access'
        );
        insert ps;

        UJJAYINICustomerAccessService.CUSTOMER_PERMISSION_SETS =
            new Set<String>{ ps.Name };

        Set<Id> me = new Set<Id>{ UserInfo.getUserId() };

        Test.startTest();
        UJJAYINICustomerAccessService.assign(me);
        UJJAYINICustomerAccessService.assign(me); // no duplicates
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM PermissionSetAssignment
             WHERE AssigneeId = :UserInfo.getUserId()
             AND PermissionSetId = :ps.Id]
        );
    }


    @IsTest
    static void internalUsersAreIgnored() {

        // Internal users have no ContactId, so nothing is queued.
        Test.startTest();
        UJJAYINICustomerAccessService.grantAccess(
            [SELECT Id, ContactId, IsActive FROM User WHERE Id = :UserInfo.getUserId()]
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getFutureCalls());
    }
}