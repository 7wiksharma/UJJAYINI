public without sharing class UJJAYINILoginController {

    private static final String GENERIC_ERROR =
        'We could not sign you in. Please check your email and password.';


    // =========================================================
    // SIGN IN
    // Returns the URL the browser should open after a
    // successful sign in.
    // =========================================================

    @AuraEnabled
    public static String login(
        String identifier,
        String password,
        String startUrl
    ) {

        String cleanIdentifier =
            identifier == null ? '' : identifier.trim();

        if (String.isBlank(cleanIdentifier) || String.isBlank(password)) {
            fail('Please enter your email and password.');
        }

        String username = resolveUsername(cleanIdentifier);
        String target = toSiteRelative(startUrl);

        PageReference result = null;

        try {

            result = Site.login(username, password, target);

        } catch (Exception e) {

            System.debug(
                LoggingLevel.WARN,
                'UJJAYINI sign in failed: ' + e.getMessage()
            );

            fail(GENERIC_ERROR);
        }

        if (result == null) {
            fail(GENERIC_ERROR);
        }

        // Send the customer to the real site page, not the old
        // "/ujjayinivforcesite/..." path Salesforce puts in retURL.
        return withReturnUrl(result.getUrl(), toSitePath(startUrl));
    }


    // =========================================================
    // FORGOT PASSWORD
    // Always reports success so nobody can find out which
    // emails are registered.
    // =========================================================

    @AuraEnabled
    public static Boolean forgotPassword(String identifier) {

        String cleanIdentifier =
            identifier == null ? '' : identifier.trim();

        if (String.isBlank(cleanIdentifier)) {
            fail('Please enter your email.');
        }

        try {

            Site.forgotPassword(resolveUsername(cleanIdentifier));

        } catch (Exception e) {

            System.debug(
                LoggingLevel.WARN,
                'UJJAYINI password reset failed: ' + e.getMessage()
            );
        }

        return true;
    }


    // =========================================================
    // HELPERS
    // =========================================================

    /*
     * Accepts either the Salesforce username or the customer's
     * email. Falls back to what was typed.
     */
    @TestVisible
    private static String resolveUsername(String identifier) {

        List<User> exact = [
            SELECT Username
            FROM User
            WHERE Username = :identifier
            AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (!exact.isEmpty()) {
            return exact[0].Username;
        }

        if (identifier.contains('@')) {

            List<User> byEmail = [
                SELECT Username
                FROM User
                WHERE Email = :identifier
                AND IsActive = true
                AND ContactId != null
                WITH SYSTEM_MODE
                LIMIT 2
            ];

            // Only when exactly one customer uses this email.
            if (byEmail.size() == 1) {
                return byEmail[0].Username;
            }
        }

        return identifier;
    }
    private static final String SITE_PATH = '/ujjayini';


    /*
     * Full site path to open after sign in, e.g. "/ujjayini/cart".
     * Anything that is not a same-site path goes to My Account.
     */
    @TestVisible
    private static String toSitePath(String startUrl) {

        String value = startUrl == null ? '' : startUrl.trim();

        if (
            String.isBlank(value) ||
            !value.startsWith('/') ||
            value.startsWith('//') ||
            value.contains('://') ||
            value.contains('\\')
        ) {
            return SITE_PATH + '/my-account';
        }

        if (!(value == SITE_PATH || value.startsWith(SITE_PATH + '/'))) {
            value = SITE_PATH + value;
        }

        return value;
    }


    /*
     * Replaces the retURL in Salesforce's sign-in link.
     */
    @TestVisible
    private static String withReturnUrl(String loginUrl, String sitePath) {

        if (String.isBlank(loginUrl) || !loginUrl.contains('retURL=')) {
            return loginUrl;
        }

        return loginUrl.replaceFirst(
            'retURL=[^&]*',
            'retURL=' + EncodingUtil.urlEncode(sitePath, 'UTF-8')
        );
    }

    /*
     * Only same-site paths are allowed (no open redirect).
     * "/ujjayini/cart" becomes "/cart", which Site.login expects.
     */
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
            return '/';
        }

        String prefix = Site.getPathPrefix();

        if (
            String.isNotBlank(prefix) &&
            (value == prefix || value.startsWith(prefix + '/'))
        ) {
            value = value.substring(prefix.length());
        }

        return String.isBlank(value) ? '/' : value;
    }


    private static void fail(String message) {

        AuraHandledException error = new AuraHandledException(message);

        error.setMessage(message);

        throw error;
    }
}