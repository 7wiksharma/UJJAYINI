public without sharing class UJJAYINICheckoutAddressController {

    /*
     * Used only by tests: lets a test choose the customer Contact
     * without creating a real Experience Cloud user.
     */
    @TestVisible
    private static Id testContactId;


    public class CheckoutAddress {

        @AuraEnabled public String fullName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;

        @AuraEnabled public String line1;
        @AuraEnabled public String line2;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;

        // True when the address is already stored on the current cart.
        @AuraEnabled public Boolean isSavedOnOrder;
    }


    // =========================================================
    // READ (prefill)
    //
    // 1. Address already on the current cart (Draft order)
    // 2. Address of this customer's previous order
    // 3. Contact mailing address
    // =========================================================

    @AuraEnabled
    public static CheckoutAddress getCheckoutAddress() {

        Contact customer =
            getCurrentContact();

        CheckoutAddress result =
            new CheckoutAddress();

        result.fullName = customer.Name;
        result.email = customer.Email;
        result.phone = customer.Phone;
        result.country = 'India';
        result.isSavedOnOrder = false;


        Order draft =
            findDraftOrder(customer.AccountId);

        if (
            draft != null &&
            String.isNotBlank(draft.ShippingPostalCode)
        ) {

            copyFromOrder(result, draft);

            result.isSavedOnOrder = true;

            return result;
        }


        List<Order> previous = [
            SELECT Id,
                   ShippingStreet,
                   ShippingCity,
                   ShippingState,
                   ShippingPostalCode,
                   ShippingCountry
            FROM Order
            WHERE AccountId = :customer.AccountId
            AND ShipToContactId = :customer.Id
            AND ShippingPostalCode != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!previous.isEmpty()) {

            copyFromOrder(result, previous[0]);

            return result;
        }


        if (String.isNotBlank(customer.MailingPostalCode)) {

            List<String> lines =
                splitStreet(customer.MailingStreet);

            result.line1 = lines[0];
            result.line2 = lines[1];
            result.city = customer.MailingCity;
            result.state = customer.MailingState;
            result.postalCode = customer.MailingPostalCode;

            if (String.isNotBlank(customer.MailingCountry)) {
                result.country = customer.MailingCountry;
            }
        }

        return result;
    }


    // =========================================================
    // SAVE (on the current customer's own cart only)
    // =========================================================

    @AuraEnabled
    public static CheckoutAddress saveShippingAddress(
        String phone,
        String line1,
        String line2,
        String city,
        String state,
        String postalCode,
        String country
    ) {

        String cleanPhone = trimToEmpty(phone);
        String cleanLine1 = trimToEmpty(line1);
        String cleanLine2 = trimToEmpty(line2);
        String cleanCity = trimToEmpty(city);
        String cleanState = trimToEmpty(state);
        String cleanPostal = trimToEmpty(postalCode);
        String cleanCountry = trimToEmpty(country);

        if (String.isBlank(cleanCountry)) {
            cleanCountry = 'India';
        }

        /*
         * Indian mobile number: exactly 10 digits, starting 6-9.
         * "+91 98765 43210" and "098765 43210" are accepted and
         * saved as the plain 10 digits.
         */
        String phoneDigits =
            cleanPhone.replaceAll('[^0-9]', '');

        if (phoneDigits.length() == 12 && phoneDigits.startsWith('91')) {
            phoneDigits = phoneDigits.substring(2);
        } else if (phoneDigits.length() == 11 && phoneDigits.startsWith('0')) {
            phoneDigits = phoneDigits.substring(1);
        }

        if (!Pattern.matches('[6-9][0-9]{9}', phoneDigits)) {
            fail('Please enter a valid 10-digit mobile number.');
        }

        cleanPhone = phoneDigits;

        if (String.isBlank(cleanLine1)) {
            fail('Please enter your address.');
        }

        if (String.isBlank(cleanCity)) {
            fail('Please enter your city.');
        }

        if (String.isBlank(cleanState)) {
            fail('Please enter your state.');
        }

        /*
         * The org uses State and Country picklists, so Salesforce only
         * accepts a real state name ("Madhya Pradesh"), not "MP" or
         * "m.p". Customers type short forms, so we convert them.
         */
        if (cleanCountry.equalsIgnoreCase('India')) {

            cleanCountry = 'India';

            String stateName = indianStateName(cleanState);

            if (stateName == null) {
                fail('Please enter your full state name, for example Madhya Pradesh.');
            }

            cleanState = stateName;
        }

        if (
            cleanCountry.equalsIgnoreCase('India') &&
            !Pattern.matches('[0-9]{6}', cleanPostal)
        ) {
            fail('Please enter a valid 6-digit PIN code.');
        }

        if (String.isBlank(cleanPostal)) {
            fail('Please enter your postal code.');
        }


        Contact customer =
            getCurrentContact();

        Order draft =
            findDraftOrder(customer.AccountId);

        if (draft == null) {
            fail('Your cart is empty.');
        }


        String street =
            String.isBlank(cleanLine2)
                ? cleanLine1
                : cleanLine1 + '\n' + cleanLine2;


        Order orderUpdate = new Order(
            Id = draft.Id,
            ShipToContactId = customer.Id,
            BillToContactId = customer.Id,
            ShippingStreet = street,
            ShippingCity = cleanCity,
            ShippingState = cleanState,
            ShippingPostalCode = cleanPostal,
            ShippingCountry = cleanCountry,
            BillingStreet = street,
            BillingCity = cleanCity,
            BillingState = cleanState,
            BillingPostalCode = cleanPostal,
            BillingCountry = cleanCountry
        );

        try {

            Database.update(
                orderUpdate,
                AccessLevel.SYSTEM_MODE
            );

        } catch (DmlException e) {

            // Technical detail stays in the log, never on the screen.
            System.debug(LoggingLevel.ERROR, 'UJJAYINI address save failed: ' + e.getMessage());

            String fields = String.join(e.getDmlFieldNames(0), ',').toLowerCase();

            if (fields.contains('state')) {
                fail('Please enter your full state name, for example Madhya Pradesh.');
            }
            if (fields.contains('country')) {
                fail('Please check the country.');
            }

            fail('We could not save your address. Please check the details and try again.');
        }


        /*
         * Keep the phone on the Contact (Razorpay uses it) and
         * remember the address for next time. A Contact problem
         * must never block the checkout, so allOrNone = false.
         */
        Contact contactUpdate = new Contact(
            Id = customer.Id,
            Phone = cleanPhone
        );

        if (String.isBlank(customer.MailingPostalCode)) {

            contactUpdate.MailingStreet = street;
            contactUpdate.MailingCity = cleanCity;
            contactUpdate.MailingState = cleanState;
            contactUpdate.MailingPostalCode = cleanPostal;
            contactUpdate.MailingCountry = cleanCountry;
        }

        Database.update(
            new List<Contact>{ contactUpdate },
            false,
            AccessLevel.SYSTEM_MODE
        );


        return getCheckoutAddress();
    }


    // =========================================================
    // HELPERS
    // =========================================================

    private static Contact getCurrentContact() {

        Id contactId;

        if (
            Test.isRunningTest() &&
            testContactId != null
        ) {

            contactId = testContactId;

        } else {

            User currentUser = [
                SELECT Id,
                       ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            contactId = currentUser.ContactId;
        }

        if (contactId == null) {
            fail('Please sign in to continue.');
        }

        Contact customer = [
            SELECT Id,
                   Name,
                   Email,
                   Phone,
                   AccountId,
                   MailingStreet,
                   MailingCity,
                   MailingState,
                   MailingPostalCode,
                   MailingCountry
            FROM Contact
            WHERE Id = :contactId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (customer.AccountId == null) {
            fail('Your Contact is not linked to an Account.');
        }

        return customer;
    }


    private static Order findDraftOrder(Id accountId) {

        List<Order> drafts = [
            SELECT Id,
                   ShippingStreet,
                   ShippingCity,
                   ShippingState,
                   ShippingPostalCode,
                   ShippingCountry
            FROM Order
            WHERE AccountId = :accountId
            AND Status = 'Draft'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return drafts.isEmpty()
            ? null
            : drafts[0];
    }


    private static void copyFromOrder(
        CheckoutAddress result,
        Order source
    ) {

        List<String> lines =
            splitStreet(source.ShippingStreet);

        result.line1 = lines[0];
        result.line2 = lines[1];
        result.city = source.ShippingCity;
        result.state = source.ShippingState;
        result.postalCode = source.ShippingPostalCode;

        if (String.isNotBlank(source.ShippingCountry)) {
            result.country = source.ShippingCountry;
        }
    }


    private static List<String> splitStreet(String street) {

        if (String.isBlank(street)) {
            return new List<String>{ '', '' };
        }

        String normalised =
            street.replace('\r\n', '\n');

        Integer breakAt =
            normalised.indexOf('\n');

        if (breakAt < 0) {
            return new List<String>{ normalised, '' };
        }

        return new List<String>{
            normalised.substring(0, breakAt),
            normalised.substring(breakAt + 1)
        };
    }


    // =========================================================
    // INDIAN STATE NAMES
    //
    // Each row: the official name first, then other spellings and
    // short forms people type. Matching ignores case, spaces, dots
    // and "&".
    // =========================================================

    private static final List<List<String>> INDIAN_STATES = new List<List<String>>{
        new List<String>{ 'Andhra Pradesh', 'AP' },
        new List<String>{ 'Arunachal Pradesh', 'AR' },
        new List<String>{ 'Assam', 'AS' },
        new List<String>{ 'Bihar', 'BR' },
        new List<String>{ 'Chhattisgarh', 'Chattisgarh', 'CG', 'CT' },
        new List<String>{ 'Goa', 'GA' },
        new List<String>{ 'Gujarat', 'GJ' },
        new List<String>{ 'Haryana', 'HR' },
        new List<String>{ 'Himachal Pradesh', 'HP' },
        new List<String>{ 'Jharkhand', 'JH' },
        new List<String>{ 'Karnataka', 'KA' },
        new List<String>{ 'Kerala', 'KL' },
        new List<String>{ 'Madhya Pradesh', 'MP' },
        new List<String>{ 'Maharashtra', 'MH' },
        new List<String>{ 'Manipur', 'MN' },
        new List<String>{ 'Meghalaya', 'ML' },
        new List<String>{ 'Mizoram', 'MZ' },
        new List<String>{ 'Nagaland', 'NL' },
        new List<String>{ 'Odisha', 'Orissa', 'OD', 'OR' },
        new List<String>{ 'Punjab', 'PB' },
        new List<String>{ 'Rajasthan', 'RJ' },
        new List<String>{ 'Sikkim', 'SK' },
        new List<String>{ 'Tamil Nadu', 'TN' },
        new List<String>{ 'Telangana', 'TG', 'TS' },
        new List<String>{ 'Tripura', 'TR' },
        new List<String>{ 'Uttar Pradesh', 'UP' },
        new List<String>{ 'Uttarakhand', 'Uttaranchal', 'UK', 'UT' },
        new List<String>{ 'West Bengal', 'WB' },
        new List<String>{ 'Andaman and Nicobar Islands', 'Andaman and Nicobar', 'AN' },
        new List<String>{ 'Chandigarh', 'CH' },
        new List<String>{ 'Dadra and Nagar Haveli and Daman and Diu', 'Dadra and Nagar Haveli', 'Daman and Diu', 'DN', 'DD', 'DH' },
        new List<String>{ 'Delhi', 'New Delhi', 'NCT of Delhi', 'DL' },
        new List<String>{ 'Jammu and Kashmir', 'JK' },
        new List<String>{ 'Ladakh', 'LA' },
        new List<String>{ 'Lakshadweep', 'LD' },
        new List<String>{ 'Puducherry', 'Pondicherry', 'PY' }
    };

    /*
     * "mp", "M.P", "madhya pradesh" -> the state name Salesforce
     * accepts. When State and Country picklists are on, the name is
     * taken from the org's own picklist (so its spelling always
     * matches). Returns null when the state is not recognised.
     */
    @TestVisible
    private static String indianStateName(String typed) {

        String key = stateKey(typed);

        if (String.isBlank(key)) {
            return null;
        }

        List<String> row = null;

        for (List<String> candidate : INDIAN_STATES) {
            for (String spelling : candidate) {
                if (stateKey(spelling) == key) {
                    row = candidate;
                    break;
                }
            }
            if (row != null) {
                break;
            }
        }

        if (row == null) {
            return null;
        }

        Map<String, String> picklistNames = statePicklistNames();

        if (picklistNames.isEmpty()) {
            return row[0]; // picklists off: plain text is fine
        }

        for (String spelling : row) {
            String exact = picklistNames.get(stateKey(spelling));
            if (exact != null) {
                return exact;
            }
        }

        return row[0];
    }

    // State names of the org's State picklist (empty when it is off).
    private static Map<String, String> statePicklistNames() {

        Map<String, String> names = new Map<String, String>();

        Map<String, Schema.SObjectField> fields =
            Schema.SObjectType.Order.fields.getMap();

        if (!fields.containsKey('shippingstatecode')) {
            return names;
        }

        for (Schema.PicklistEntry entry :
             fields.get('shippingstatecode').getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                names.put(stateKey(entry.getLabel()), entry.getLabel());
            }
        }

        return names;
    }

    private static String stateKey(String value) {
        if (value == null) {
            return '';
        }
        return value.toLowerCase().replace('&', 'and').replaceAll('[^a-z]', '');
    }


    private static String trimToEmpty(String value) {

        return value == null
            ? ''
            : value.trim();
    }


    private static void fail(String message) {

        AuraHandledException error =
            new AuraHandledException(message);

        error.setMessage(message);

        throw error;
    }
}