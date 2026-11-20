public without sharing class UJJAYINIEnquiryController {

    private static final Set<String> SUBJECTS = new Set<String>{
        'General Enquiry',
        'Product Information',
        'Private Viewing',
        'Order & Delivery',
        'Service & Repair',
        'Partnership',
        'Other'
    };

    private static final Integer MAX_MESSAGE_LENGTH = 2000;


    public class EnquiryResult {

        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }


    // =========================================================
    // CONTACT FORM -> LEAD
    //
    // "website" is a hidden honeypot field. People never see it,
    // bots usually fill it. When it is filled we report success
    // but create nothing.
    // =========================================================

    @AuraEnabled
    public static EnquiryResult submitEnquiry(
        String name,
        String email,
        String phone,
        String subject,
        String message,
        String website
    ) {

        EnquiryResult result = success(
            'Thank you. A member of the House of UJJAYINI will be in touch.'
        );

        if (String.isNotBlank(website)) {
            return result;
        }

        String cleanName = trimToEmpty(name);
        String cleanEmail = trimToEmpty(email);
        String cleanPhone = trimToEmpty(phone);
        String cleanSubject = trimToEmpty(subject);
        String cleanMessage = trimToEmpty(message);

        if (cleanName.length() < 2 || cleanName.length() > 120) {
            fail('Please enter your name.');
        }

        if (!isValidEmail(cleanEmail)) {
            fail('Please enter a valid email address.');
        }

        if (String.isNotBlank(cleanPhone)) {

            String digits = cleanPhone.replaceAll('[^0-9]', '');

            if (digits.length() < 10 || digits.length() > 13) {
                fail('Please enter a valid phone number.');
            }
        }

        if (!SUBJECTS.contains(cleanSubject)) {
            cleanSubject = 'General Enquiry';
        }

        if (cleanMessage.length() < 5) {
            fail('Please tell us a little about your enquiry.');
        }

        if (cleanMessage.length() > MAX_MESSAGE_LENGTH) {
            cleanMessage = cleanMessage.left(MAX_MESSAGE_LENGTH);
        }

        List<String> nameParts = splitName(cleanName);

        Lead lead = new Lead(
            FirstName = nameParts[0],
            LastName = nameParts[1],
            Company = 'Individual',
            Email = cleanEmail,
            Phone = String.isBlank(cleanPhone) ? null : cleanPhone,
            LeadSource = 'Web',
            Description =
                'Subject: ' + cleanSubject + '\n' +
                'Sent from: UJJAYINI website footer\n\n' +
                cleanMessage
        );

        insertLead(lead);

        return result;
    }


    // =========================================================
    // THE JOURNAL (newsletter) -> LEAD
    // =========================================================

    @AuraEnabled
    public static EnquiryResult subscribeToJournal(
        String email,
        String website
    ) {

        EnquiryResult result = success(
            'Welcome to The UJJAYINI Journal.'
        );

        if (String.isNotBlank(website)) {
            return result;
        }

        String cleanEmail = trimToEmpty(email);

        if (!isValidEmail(cleanEmail)) {
            fail('Please enter a valid email address.');
        }

        Lead lead = new Lead(
            LastName = 'Journal Subscriber',
            Company = 'The UJJAYINI Journal',
            Email = cleanEmail,
            LeadSource = 'Web',
            Description =
                'Subscribed to The UJJAYINI Journal from the website footer.'
        );

        insertLead(lead);

        return result;
    }


    // =========================================================
    // HELPERS
    // =========================================================

    private static void insertLead(Lead lead) {

        Database.DMLOptions options = new Database.DMLOptions();

        // A matching lead must not stop a customer's enquiry.
        options.DuplicateRuleHeader.allowSave = true;

        // Use the org's default lead assignment rule, if any.
        options.AssignmentRuleHeader.useDefaultRule = true;

        Database.SaveResult saveResult =
            Database.insert(
                lead,
                options,
                AccessLevel.SYSTEM_MODE
            );

        if (!saveResult.isSuccess()) {

            System.debug(
                LoggingLevel.ERROR,
                'UJJAYINI lead creation failed: ' +
                saveResult.getErrors()[0].getMessage()
            );

            fail(
                'We could not send your message just now. ' +
                'Please try again in a moment.'
            );
        }
    }


    @TestVisible
    private static List<String> splitName(String fullName) {

        String clean = fullName.normalizeSpace();

        Integer lastSpace = clean.lastIndexOf(' ');

        if (lastSpace <= 0) {
            return new List<String>{ null, clean.left(80) };
        }

        return new List<String>{
            clean.substring(0, lastSpace).left(40),
            clean.substring(lastSpace + 1).left(80)
        };
    }


    private static Boolean isValidEmail(String email) {

        return String.isNotBlank(email) &&
            email.length() <= 80 &&
            Pattern.matches(
                '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$',
                email
            );
    }


    private static EnquiryResult success(String message) {

        EnquiryResult result = new EnquiryResult();

        result.success = true;
        result.message = message;

        return result;
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