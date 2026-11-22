trigger UJJAYINIUserTrigger on User (after insert) {

    UJJAYINICustomerAccessService.grantAccess(Trigger.new);
}