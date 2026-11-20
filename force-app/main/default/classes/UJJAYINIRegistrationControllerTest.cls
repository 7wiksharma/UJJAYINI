@IsTest
private class UJJAYINIRegistrationControllerTest {

    private static String tryRegister(
        String email,
        String password,
        String confirm,
        String website
    ) {

        try {

            UJJAYINIRegistrationController.register(
                'Satwik', 'Sharma', email, '9876543210',
                password, confirm, '/', website
            );

        } catch (AuraHandledException e) {

            return e.getMessage();
        }

        return null;
    }


    @IsTest
    static void invalidEmailIsRejected() {

        String message = tryRegister('not-an-email', 'Secret#123', 'Secret#123', null);

        System.assert(message.contains('valid email'));
    }


    @IsTest
    static void mismatchedPasswordsAreRejected() {

        String message = tryRegister('a@example.com', 'Secret#123', 'Other#123', null);

        System.assert(message.contains('do not match'));
    }


    @IsTest
    static void shortPasswordIsRejected() {

        String message = tryRegister('a@example.com', 'short', 'short', null);

        System.assert(message.contains('at least 8'));
    }


    @IsTest
    static void honeypotIsRejected() {

        String message = tryRegister('a@example.com', 'Secret#123', 'Secret#123', 'spam');

        System.assertNotEquals(null, message);
        System.assertEquals(0, [SELECT COUNT() FROM Account]);
    }


    @IsTest
    static void usernameIsUniqueAndOnTheSiteDomain() {

        String username =
            UJJAYINIRegistrationController.buildUsername('satwik@example.com');

        System.assert(username.startsWith('satwik.'));
        System.assert(username.endsWith('@ujjayini.com'));
    }


    @IsTest
    static void outsideLinksAreIgnored() {

        System.assertEquals(
            '/my-account',
            UJJAYINIRegistrationController.toSiteRelative('https://evil.example')
        );

        System.assertEquals(
            '/cart',
            UJJAYINIRegistrationController.toSiteRelative('/cart')
        );
    }
}