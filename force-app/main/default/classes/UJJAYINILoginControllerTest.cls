@IsTest
private class UJJAYINILoginControllerTest {

    @IsTest
    static void onlySameSitePathsAreKept() {

        System.assertEquals('/', UJJAYINILoginController.toSiteRelative(null));
        System.assertEquals('/', UJJAYINILoginController.toSiteRelative('https://evil.example'));
        System.assertEquals('/', UJJAYINILoginController.toSiteRelative('//evil.example'));
        System.assertEquals('/cart', UJJAYINILoginController.toSiteRelative('/cart'));
    }


    @IsTest
    static void usernameIsFoundExactly() {

        String myUsername = UserInfo.getUserName();

        System.assertEquals(
            myUsername,
            UJJAYINILoginController.resolveUsername(myUsername)
        );
    }


    @IsTest
    static void unknownEmailIsReturnedAsTyped() {

        System.assertEquals(
            'nobody@example.com',
            UJJAYINILoginController.resolveUsername('nobody@example.com')
        );
    }


    @IsTest
    static void blankDetailsAreRejected() {

        Boolean rejected = false;

        try {

            UJJAYINILoginController.login('', '', '/');

        } catch (AuraHandledException e) {

            rejected = true;
        }

        System.assertEquals(true, rejected);
    }


    @IsTest
    static void failedSignInShowsAGenericMessage() {

        Boolean rejected = false;

        try {

            // Outside a site, Site.login cannot succeed.
            UJJAYINILoginController.login('someone@example.com', 'wrong', '/');

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('could not sign you in'));
        }

        System.assertEquals(true, rejected);
    }


    @IsTest
    static void forgotPasswordAlwaysSucceeds() {

        System.assertEquals(
            true,
            UJJAYINILoginController.forgotPassword('nobody@example.com')
        );
    }

    @IsTest
    static void returnUrlPointsToTheSitePage() {

        System.assertEquals('/ujjayini/cart', UJJAYINILoginController.toSitePath('/ujjayini/cart'));
        System.assertEquals('/ujjayini/cart', UJJAYINILoginController.toSitePath('/cart'));
        System.assertEquals('/ujjayini/my-account', UJJAYINILoginController.toSitePath('https://evil.example'));

        String fixedUrl = UJJAYINILoginController.withReturnUrl(
            'https://x.example/secur/frontdoor.jsp?sid=1&retURL=%2Fujjayinivforcesite%2Fcart&a=2',
            '/ujjayini/cart'
        );

        System.assert(fixedUrl.contains('retURL=%2Fujjayini%2Fcart&'));
    }
}