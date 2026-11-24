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

        Database.update(
            orderUpdate,
            AccessLevel.SYSTEM_MODE
        );


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