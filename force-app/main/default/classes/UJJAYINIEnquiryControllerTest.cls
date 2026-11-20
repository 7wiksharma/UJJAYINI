@IsTest
private class UJJAYINIEnquiryControllerTest {

    @IsTest
    static void enquiryCreatesALead() {

        UJJAYINIEnquiryController.EnquiryResult result =
            UJJAYINIEnquiryController.submitEnquiry(
                'Satwik Sharma',
                'satwik@example.com',
                '9876543210',
                'Private Viewing',
                'I would like to see the Hiranya collection.',
                null
            );

        System.assertEquals(true, result.success);

        Lead lead = [
            SELECT FirstName, LastName, Email, Phone, LeadSource, Description
            FROM Lead
            LIMIT 1
        ];

        System.assertEquals('Satwik', lead.FirstName);
        System.assertEquals('Sharma', lead.LastName);
        System.assertEquals('satwik@example.com', lead.Email);
        System.assertEquals('Web', lead.LeadSource);
        System.assert(lead.Description.contains('Private Viewing'));
    }


    @IsTest
    static void invalidEmailIsRejected() {

        Boolean rejected = false;

        try {

            UJJAYINIEnquiryController.submitEnquiry(
                'Satwik Sharma', 'not-an-email', null,
                'General Enquiry', 'Hello there.', null
            );

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('email'));
        }

        System.assertEquals(true, rejected);
        System.assertEquals(0, [SELECT COUNT() FROM Lead]);
    }


    @IsTest
    static void honeypotCreatesNothing() {

        UJJAYINIEnquiryController.EnquiryResult result =
            UJJAYINIEnquiryController.submitEnquiry(
                'Bot', 'bot@example.com', null,
                'General Enquiry', 'Buy cheap things.', 'http://spam.example'
            );

        System.assertEquals(true, result.success);
        System.assertEquals(0, [SELECT COUNT() FROM Lead]);
    }


    @IsTest
    static void journalSubscriptionCreatesALead() {

        UJJAYINIEnquiryController.subscribeToJournal(
            'reader@example.com',
            null
        );

        Lead lead = [SELECT LastName, Email FROM Lead LIMIT 1];

        System.assertEquals('Journal Subscriber', lead.LastName);
        System.assertEquals('reader@example.com', lead.Email);
    }


    @IsTest
    static void singleWordNameBecomesLastName() {

        List<String> parts = UJJAYINIEnquiryController.splitName('Satwik');

        System.assertEquals(null, parts[0]);
        System.assertEquals('Satwik', parts[1]);
    }
}