/*
 * Runs as the Automated Process user (a system user), not as the
 * site guest user who registered the customer. That is why the
 * permission set can be assigned here.
 */
trigger UJJAYINIAccessRequestTrigger on UJJAYINI_Access_Request__e (after insert) {

    Set<Id> userIds = new Set<Id>();

    for (UJJAYINI_Access_Request__e request : Trigger.new) {
        if (String.isNotBlank(request.User_Id__c)) {
            userIds.add(Id.valueOf(request.User_Id__c));
        }
    }

    UJJAYINICustomerAccessService.assign(userIds);
}