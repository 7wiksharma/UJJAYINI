trigger UJJAYINIContactAccountTrigger on Contact (before insert) {

    UJJAYINIPersonalAccountService.assignPersonalAccounts(Trigger.new);
}