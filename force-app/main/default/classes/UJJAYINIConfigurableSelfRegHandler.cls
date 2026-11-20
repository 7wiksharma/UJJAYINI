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
         * One customer, one account: never register two
         * customers with the same email.
         */
        Integer existingCustomers = [
            SELECT COUNT()
            FROM User
            WHERE Email = :userRecord.Email
            AND IsActive = true
            AND ContactId != null
        ];

        if (existingCustomers > 0) {
            throw new IllegalArgumentException(
                'An account with this email already exists. Please sign in.'
            );
        }

        /*
         * Every customer gets their OWN account, so carts,
         * orders and the Collector's Vault are never shared
         * between customers. The "accountId" from the site
         * settings is intentionally not used.
         */
        Id customerAccountId =
            createCustomerAccount(userRecord);

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
     * Creates the customer's own account.
     *
     * Salesforce requires the owner of a portal/community
     * account to have a Salesforce Role, so the account is
     * owned by the registration user, who must have one.
     */
    private Id createCustomerAccount(
        User userRecord
    ) {

        User currentUser = [
            SELECT Id,
                   UserRoleId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (currentUser.UserRoleId == null) {

            throw new IllegalArgumentException(
                'The registration user must have a Salesforce role.'
            );
        }

        String accountName =
            (
                (String.isBlank(userRecord.FirstName)
                    ? ''
                    : userRecord.FirstName + ' ') +
                userRecord.LastName
            ).trim();

        Account customerAccount = new Account(
            Name = accountName.left(255),
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

        userRecord.Email =
            userRecord.Email.trim().toLowerCase();

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

        String localPart =
            email.substringBefore('@')
                .replaceAll('[^a-zA-Z0-9._-]', '');

        if (String.isBlank(localPart)) {
            localPart = 'collector';
        }

        return localPart.left(30)
            + '.'
            + String.valueOf(CURRENT_TIME)
            + '@ujjayini.com';
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