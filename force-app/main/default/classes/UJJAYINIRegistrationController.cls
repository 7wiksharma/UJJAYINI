public without sharing class UJJAYINIRegistrationController {

    // The existing customer account; its owner (who has a role)
    // becomes the owner of every new customer account.
    private static final String OWNER_TEMPLATE_ACCOUNT = 'UJJAYINI Customers';

    private static final String GENERIC_ERROR =
        'We could not create your account just now. Please try again.';


    /*
     * Creates the customer's own Account and community user, then
     * signs them in. Returns the URL to open, or null when the
     * account was created but automatic sign in was not possible.
     * "website" is a hidden honeypot field.
     */
    @AuraEnabled
    public static String register(
        String firstName,
        String lastName,
        String email,
        String phone,
        String password,
        String confirmPassword,
        String startUrl,
        String website
    ) {

        if (String.isNotBlank(website)) {
            fail(GENERIC_ERROR);
        }

        String cleanFirst = trimToEmpty(firstName);
        String cleanLast = trimToEmpty(lastName);
        String cleanEmail = trimToEmpty(email).toLowerCase();
        String cleanPhone = trimToEmpty(phone);

        if (String.isBlank(cleanFirst) || cleanFirst.length() > 40) {
            fail('Please enter your first name.');
        }

        if (String.isBlank(cleanLast) || cleanLast.length() > 80) {
            fail('Please enter your last name.');
        }

        if (
            cleanEmail.length() > 80 ||
            !Pattern.matches(
                '^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}$',
                cleanEmail
            )
        ) {
            fail('Please enter a valid email address.');
        }

        if (String.isNotBlank(cleanPhone)) {

            String digits = cleanPhone.replaceAll('[^0-9]', '');

            if (digits.length() < 10 || digits.length() > 13) {
                fail('Please enter a valid phone number.');
            }
        }

        if (String.isBlank(password) || password.length() < 8) {
            fail('Your password must be at least 8 characters.');
        }

        if (password != confirmPassword) {
            fail('The passwords do not match.');
        }

        Integer existing = [
            SELECT COUNT()
            FROM User
            WHERE Email = :cleanEmail
            AND IsActive = true
            AND ContactId != null
            WITH SYSTEM_MODE
        ];

        if (existing > 0) {
            fail('An account with this email already exists. Please sign in.');
        }

        User newUser = new User(
            FirstName = cleanFirst,
            LastName = cleanLast,
            Email = cleanEmail,
            Username = buildUsername(cleanEmail),
            CommunityNickname = buildNickname(),
            Phone = String.isBlank(cleanPhone) ? null : cleanPhone
        );

        // Org password policy check, before anything is created.
        try {

            Site.validatePassword(newUser, password, confirmPassword);

        } catch (Exception e) {

            fail(e.getMessage());
        }

        Id ownerId = resolveOwnerId();

        Savepoint sp = Database.setSavepoint();

        String userId = null;

        try {

            Account customerAccount = new Account(
                Name = (cleanFirst + ' ' + cleanLast).left(255),
                OwnerId = ownerId
            );

            Database.insert(customerAccount, AccessLevel.SYSTEM_MODE);

            userId = Site.createExternalUser(
                newUser,
                customerAccount.Id,
                password
            );

        } catch (Site.ExternalUserCreateException e) {

            Database.rollback(sp);

            List<String> messages = e.getDisplayMessages();

            fail(
                messages == null || messages.isEmpty()
                    ? GENERIC_ERROR
                    : String.join(messages, ' ')
            );

        } catch (Exception e) {

            Database.rollback(sp);

            System.debug(
                LoggingLevel.ERROR,
                'UJJAYINI registration failed: ' + e.getMessage()
            );

            fail(GENERIC_ERROR);
        }

        if (userId == null) {

            Database.rollback(sp);

            fail(GENERIC_ERROR);
        }

        PageReference signedIn = null;

        try {

            signedIn = Site.login(
                newUser.Username,
                password,
                toSiteRelative(startUrl)
            );

        } catch (Exception e) {

            System.debug(
                LoggingLevel.WARN,
                'UJJAYINI automatic sign in failed: ' + e.getMessage()
            );
        }

        return signedIn == null ? null : signedIn.getUrl();
    }


    // =========================================================
    // HELPERS
    // =========================================================

    private static Id resolveOwnerId() {

        List<Account> template = [
            SELECT OwnerId
            FROM Account
            WHERE Name = :OWNER_TEMPLATE_ACCOUNT
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (template.isEmpty()) {

            System.debug(
                LoggingLevel.ERROR,
                'UJJAYINI registration: owner template account is missing.'
            );

            fail(GENERIC_ERROR);
        }

        return template[0].OwnerId;
    }


    @TestVisible
    private static String buildUsername(String email) {

        String localPart =
            email.substringBefore('@').replaceAll('[^a-z0-9._-]', '');

        if (String.isBlank(localPart)) {
            localPart = 'collector';
        }

        return localPart.left(30) + '.' +
            String.valueOf(Datetime.now().getTime()) + '@ujjayini.com';
    }


    private static String buildNickname() {

        return ('UJJAYINI' + String.valueOf(Datetime.now().getTime()) +
            String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 1000))
        ).left(40);
    }


    @TestVisible
    private static String toSiteRelative(String startUrl) {

        String value = startUrl == null ? '' : startUrl.trim();

        if (
            String.isBlank(value) ||
            !value.startsWith('/') ||
            value.startsWith('//') ||
            value.contains('://') ||
            value.contains('\\')
        ) {
            return '/my-account';
        }

        String prefix = Site.getPathPrefix();

        if (
            String.isNotBlank(prefix) &&
            (value == prefix || value.startsWith(prefix + '/'))
        ) {
            value = value.substring(prefix.length());
        }

        return String.isBlank(value) ? '/my-account' : value;
    }


    private static String trimToEmpty(String value) {
        return value == null ? '' : value.trim();
    }


    private static void fail(String message) {

        AuraHandledException error = new AuraHandledException(message);

        error.setMessage(message);

        throw error;
    }
}