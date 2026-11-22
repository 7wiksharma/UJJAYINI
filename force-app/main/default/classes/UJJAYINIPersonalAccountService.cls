public without sharing class UJJAYINIPersonalAccountService {

    // The shared account that site registration assigns by default.
    @TestVisible
    private static final String SHARED_ACCOUNT_NAME = 'UJJAYINI Customers';


    /*
     * Called before a Contact is inserted. Any contact that would
     * land on the shared "UJJAYINI Customers" account is moved to a
     * brand new account of its own, so customers never share a cart,
     * orders or a Collector's Vault.
     */
    public static void assignPersonalAccounts(List<Contact> contacts) {

        if (contacts == null || contacts.isEmpty()) {
            return;
        }

        List<Account> shared = [
            SELECT Id,
                   OwnerId
            FROM Account
            WHERE Name = :SHARED_ACCOUNT_NAME
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (shared.isEmpty()) {
            return;
        }

        Id sharedAccountId = shared[0].Id;

        // This owner already has the role Salesforce requires for
        // customer accounts.
        Id ownerId = shared[0].OwnerId;

        List<Contact> targets = new List<Contact>();
        List<Account> personalAccounts = new List<Account>();

        for (Contact contact : contacts) {

            if (contact.AccountId != sharedAccountId) {
                continue;
            }

            String name =
                (
                    (String.isBlank(contact.FirstName)
                        ? ''
                        : contact.FirstName + ' ') +
                    (contact.LastName == null ? '' : contact.LastName)
                ).trim();

            if (String.isBlank(name)) {
                name = 'UJJAYINI Collector';
            }

            targets.add(contact);

            personalAccounts.add(
                new Account(
                    Name = name.left(255),
                    OwnerId = ownerId
                )
            );
        }

        if (targets.isEmpty()) {
            return;
        }

        Database.insert(personalAccounts, AccessLevel.SYSTEM_MODE);

        for (Integer i = 0; i < targets.size(); i++) {
            targets[i].AccountId = personalAccounts[i].Id;
        }
    }
}