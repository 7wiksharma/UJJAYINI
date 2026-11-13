global with sharing class UJJAYINIConfigurableSelfRegHandler
    implements Auth.ConfigurableSelfRegHandler {

    private final Long CURRENT_TIME = Datetime.now().getTime();

    global Id createUser(
        Id accountId,
        Id profileId,
        Map<SObjectField, String> registrationAttributes,
        String password
    ) {

        if (profileId == null) {
            throw new IllegalArgumentException(
                'External user profile is required.'
            );
        }

        /*
         * Determine the customer account.
         *
         * If Salesforce provides an Account Id,
         * use that account.
         *
         * Otherwise use/create the default
         * UJJAYINI Customers account.
         */
        Id customerAccountId = accountId;

        if (customerAccountId == null) {
            customerAccountId = getDefaultCustomerAccountId();
        }

        /*
         * Build the external User record.
         */
        User userRecord = new User();

        userRecord.ProfileId = profileId;

        /*
         * Copy registration fields supplied by
         * the Experience Cloud registration page.
         */
        if (registrationAttributes != null) {

            for (SObjectField field :
                registrationAttributes.keySet()) {

                String value =
                    registrationAttributes.get(field);

                if (value != null) {
                    userRecord.put(field, value);
                }
            }
        }

        /*
         * Populate Salesforce-required User fields.
         */
        populateRequiredUserFields(userRecord);

        /*
         * Create the Contact that will be associated
         * with the external User.
         */
        Contact customerContact = new Contact(
            FirstName = userRecord.FirstName,
            LastName = userRecord.LastName,
            Email = userRecord.Email,
            AccountId = customerAccountId
        );

        insert customerContact;

        /*
         * Link the external User to the Contact.
         */
        userRecord.ContactId = customerContact.Id;

        /*
         * Set required locale information.
         */
        userRecord.LanguageLocaleKey =
            UserInfo.getLocale();

        userRecord.LocaleSidKey =
            UserInfo.getLocale();

        userRecord.EmailEncodingKey =
            'UTF-8';

        userRecord.TimeZoneSidKey =
            UserInfo.getTimeZone().getID();

        /*
         * If the registration page does not provide
         * a password, generate one.
         */
        if (String.isBlank(password)) {
            password = generateRandomPassword();
        }

        /*
         * Validate the password before inserting
         * the external User.
         */
        Site.validatePassword(
            userRecord,
            password,
            password
        );

        /*
         * Create the external User.
         */
        insert userRecord;

        /*
         * Set the user's password.
         */
        System.setPassword(
            userRecord.Id,
            password
        );

        return userRecord.Id;
    }


    /*
     * Gets or creates the default UJJAYINI customer account.
     *
     * Salesforce requires the owner of a portal/community
     * account to have a Salesforce Role.
     */
    private Id getDefaultCustomerAccountId() {

        /*
         * Find an existing UJJAYINI customer account.
         */
        List<Account> existingAccounts = [
            SELECT Id,
                   OwnerId
            FROM Account
            WHERE Name = 'UJJAYINI Customers'
            LIMIT 1
        ];

        /*
         * Get the user executing registration.
         */
        User currentUser = [
            SELECT Id,
                   UserRoleId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        /*
         * The registration user must have a Salesforce Role.
         */
        if (currentUser.UserRoleId == null) {

            throw new IllegalArgumentException(
                'The registration user must have a Salesforce role.'
            );
        }

        /*
         * If the account already exists,
         * make sure its owner is the current
         * registration user.
         */
        if (!existingAccounts.isEmpty()) {

            Account existingAccount =
                existingAccounts[0];

            if (existingAccount.OwnerId != currentUser.Id) {

                existingAccount.OwnerId =
                    currentUser.Id;

                update existingAccount;
            }

            return existingAccount.Id;
        }

        /*
         * Create the default UJJAYINI customer account
         * with an owner who definitely has a role.
         */
        Account customerAccount = new Account(
            Name = 'UJJAYINI Customers',
            OwnerId = currentUser.Id
        );

        insert customerAccount;

        return customerAccount.Id;
    }


    /*
     * Populate required Salesforce User fields.
     */
    private void populateRequiredUserFields(
        User userRecord
    ) {

        if (String.isBlank(userRecord.FirstName)) {

            userRecord.FirstName =
                'UJJAYINI';
        }

        if (String.isBlank(userRecord.LastName)) {

            userRecord.LastName =
                'Customer' +
                String.valueOf(CURRENT_TIME);
        }

        if (String.isBlank(userRecord.Email)) {

            throw new IllegalArgumentException(
                'Email is required for UJJAYINI registration.'
            );
        }

        if (String.isBlank(userRecord.Username)) {

            userRecord.Username =
                generateUsername(
                    userRecord.Email
                );
        }

        if (String.isBlank(userRecord.Alias)) {

            userRecord.Alias =
                generateAlias();
        }

        if (String.isBlank(
            userRecord.CommunityNickname
        )) {

            userRecord.CommunityNickname =
                generateCommunityNickname();
        }
    }


    /*
     * Generate a globally unique Salesforce username.
     */
    private String generateUsername(
        String email
    ) {

        String username =
            email.substringBefore('@')
            + '.'
            + String.valueOf(CURRENT_TIME)
            + '@ujjayini.com';

        return username;
    }


    /*
     * Generate a Salesforce-compatible Alias.
     */
    private String generateAlias() {

        String value =
            String.valueOf(CURRENT_TIME);

        return value.substring(
            Math.max(
                0,
                value.length() - 8
            )
        );
    }


    /*
     * Generate a unique Community Nickname.
     */
    private String generateCommunityNickname() {

        return 'UJJAYINI' +
            String.valueOf(CURRENT_TIME);
    }


    /*
     * Generate a fallback password when
     * registration does not provide one.
     */
    private String generateRandomPassword() {

        return 'Uj@' +
            String.valueOf(CURRENT_TIME) +
            '#A1';
    }
}