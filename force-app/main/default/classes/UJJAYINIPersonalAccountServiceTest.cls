@IsTest
private class UJJAYINIPersonalAccountServiceTest {

    @IsTest
    static void contactOnSharedAccountGetsItsOwnAccount() {

        Account shared = new Account(
            Name = UJJAYINIPersonalAccountService.SHARED_ACCOUNT_NAME
        );
        insert shared;

        Contact customer = new Contact(
            FirstName = 'Jhon',
            LastName = 'Wick',
            Email = 'jhon@example.com',
            AccountId = shared.Id
        );
        insert customer;

        Contact saved = [
            SELECT AccountId, Account.Name, Account.OwnerId
            FROM Contact
            WHERE Id = :customer.Id
        ];

        System.assertNotEquals(shared.Id, saved.AccountId);
        System.assertEquals('Jhon Wick', saved.Account.Name);
        System.assertEquals(
            [SELECT OwnerId FROM Account WHERE Id = :shared.Id].OwnerId,
            saved.Account.OwnerId
        );
    }


    @IsTest
    static void otherContactsAreLeftAlone() {

        insert new Account(
            Name = UJJAYINIPersonalAccountService.SHARED_ACCOUNT_NAME
        );

        Account other = new Account(Name = 'Some Business');
        insert other;

        Contact contact = new Contact(
            LastName = 'Partner',
            AccountId = other.Id
        );
        insert contact;

        System.assertEquals(
            other.Id,
            [SELECT AccountId FROM Contact WHERE Id = :contact.Id].AccountId
        );
    }


    @IsTest
    static void manyContactsGetSeparateAccounts() {

        Account shared = new Account(
            Name = UJJAYINIPersonalAccountService.SHARED_ACCOUNT_NAME
        );
        insert shared;

        List<Contact> contacts = new List<Contact>();

        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Collector',
                LastName = 'No' + i,
                AccountId = shared.Id
            ));
        }

        insert contacts;

        Set<Id> accountIds = new Set<Id>();

        for (Contact c : [SELECT AccountId FROM Contact WHERE Id IN :contacts]) {
            accountIds.add(c.AccountId);
        }

        System.assertEquals(5, accountIds.size());
        System.assert(!accountIds.contains(shared.Id));
    }
}