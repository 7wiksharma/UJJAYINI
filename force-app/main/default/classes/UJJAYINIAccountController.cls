public without sharing class UJJAYINIAccountController {

    /*
     * Used only by tests: lets a test choose the customer Contact
     * without creating a real Experience Cloud user.
     */
    @TestVisible
    private static Id testContactId;


    // Collector standing, by number of timepieces owned.
    private static final List<String> TIER_NAMES =
        new List<String>{ 'Initiate', 'Collector', 'Connoisseur', 'Patron of Time' };

    private static final List<Integer> TIER_THRESHOLDS =
        new List<Integer>{ 0, 1, 2, 4 };


    public class AccountSummary {

        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String fullName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;

        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;

        @AuraEnabled public Date memberSince;

        @AuraEnabled public Integer timepiecesOwned;
        @AuraEnabled public Integer ordersPlaced;
        @AuraEnabled public Integer activeWarranties;
        @AuraEnabled public Integer openServiceRequests;
        @AuraEnabled public Decimal collectionValue;

        @AuraEnabled public String tierName;
        @AuraEnabled public Integer tierIndex;
        @AuraEnabled public String nextTierName;
        @AuraEnabled public Integer piecesToNextTier;
        @AuraEnabled public Integer tierProgress;
    }


    // =========================================================
    // READ
    // =========================================================

    @AuraEnabled
    public static AccountSummary getMyAccount() {

        try {

            return buildSummary();

        } catch (AuraHandledException e) {

            throw e;

        } catch (Exception e) {

            fail(e.getMessage());

            return null;
        }
    }


    // =========================================================
    // UPDATE (phone and address of the customer's own Contact)
    // =========================================================

    @AuraEnabled
    public static AccountSummary updateMyDetails(
        String phone,
        String street,
        String city,
        String state,
        String postalCode,
        String country
    ) {

        String cleanPhone = trimToEmpty(phone);
        String cleanStreet = trimToEmpty(street);
        String cleanCity = trimToEmpty(city);
        String cleanState = trimToEmpty(state);
        String cleanPostal = trimToEmpty(postalCode);
        String cleanCountry = trimToEmpty(country);

        if (String.isBlank(cleanCountry)) {
            cleanCountry = 'India';
        }

        if (String.isNotBlank(cleanPhone)) {

            String digits = cleanPhone.replaceAll('[^0-9]', '');

            if (digits.length() < 10 || digits.length() > 13) {
                fail('Please enter a valid phone number.');
            }
        }

        Boolean hasAddress =
            String.isNotBlank(cleanStreet) ||
            String.isNotBlank(cleanCity) ||
            String.isNotBlank(cleanPostal);

        if (hasAddress) {

            if (String.isBlank(cleanStreet) || String.isBlank(cleanCity)) {
                fail('Please enter your full address and city.');
            }

            if (
                cleanCountry.equalsIgnoreCase('India') &&
                !Pattern.matches('[0-9]{6}', cleanPostal)
            ) {
                fail('Please enter a valid 6-digit PIN code.');
            }
        }

        Contact customer = getCurrentContact();

        Database.update(
            new Contact(
                Id = customer.Id,
                Phone = cleanPhone,
                MailingStreet = cleanStreet,
                MailingCity = cleanCity,
                MailingState = cleanState,
                MailingPostalCode = cleanPostal,
                MailingCountry = hasAddress ? cleanCountry : null
            ),
            AccessLevel.SYSTEM_MODE
        );

        return buildSummary();
    }


    // =========================================================
    // SUMMARY
    // =========================================================

    private static AccountSummary buildSummary() {

        Contact customer = getCurrentContact();

        AccountSummary summary = new AccountSummary();

        summary.firstName = customer.FirstName;
        summary.lastName = customer.LastName;
        summary.fullName = customer.Name;
        summary.email = customer.Email;
        summary.phone = customer.Phone;

        summary.street = customer.MailingStreet;
        summary.city = customer.MailingCity;
        summary.state = customer.MailingState;
        summary.postalCode = customer.MailingPostalCode;
        summary.country = customer.MailingCountry;

        User currentUser = [
            SELECT CreatedDate
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        summary.memberSince = currentUser.CreatedDate.date();

        Id accountId = customer.AccountId;

        // Timepieces and collection value (cancelled ones excluded)
        AggregateResult assetTotals = [
            SELECT SUM(Quantity) pieces,
                   SUM(Price) value
            FROM Asset
            WHERE AccountId = :accountId
            AND SerialNumber LIKE 'UJJAYINI-%'
            AND Status != 'Obsolete'
            WITH SYSTEM_MODE
        ];

        Decimal pieces = (Decimal) assetTotals.get('pieces');
        Decimal value = (Decimal) assetTotals.get('value');

        summary.timepiecesOwned = pieces == null ? 0 : pieces.intValue();
        summary.collectionValue = value == null ? 0 : value;

        summary.ordersPlaced = [
            SELECT COUNT()
            FROM Order
            WHERE AccountId = :accountId
            AND Status != 'Draft'
            AND Is_Cancelled__c = false
            WITH SYSTEM_MODE
        ];

        summary.activeWarranties = [
            SELECT COUNT()
            FROM Warranty__c
            WHERE Asset__r.AccountId = :accountId
            AND Asset__r.Status != 'Obsolete'
            AND Warranty_Status__c = 'Active'
            WITH SYSTEM_MODE
        ];

        summary.openServiceRequests = [
            SELECT COUNT()
            FROM Service_Request__c
            WHERE Customer__c = :customer.Id
            AND Case__r.IsClosed = false
            WITH SYSTEM_MODE
        ];

        applyTier(summary);

        return summary;
    }


    @TestVisible
    private static void applyTier(AccountSummary summary) {

        Integer owned = summary.timepiecesOwned == null ? 0 : summary.timepiecesOwned;

        Integer index = 0;

        for (Integer i = 0; i < TIER_THRESHOLDS.size(); i++) {
            if (owned >= TIER_THRESHOLDS[i]) {
                index = i;
            }
        }

        summary.tierIndex = index;
        summary.tierName = TIER_NAMES[index];

        if (index < TIER_NAMES.size() - 1) {

            Integer currentFloor = TIER_THRESHOLDS[index];
            Integer nextFloor = TIER_THRESHOLDS[index + 1];

            summary.nextTierName = TIER_NAMES[index + 1];
            summary.piecesToNextTier = nextFloor - owned;
            summary.tierProgress =
                Math.round(
                    100.0 * (owned - currentFloor) / (nextFloor - currentFloor)
                );

        } else {

            summary.nextTierName = null;
            summary.piecesToNextTier = 0;
            summary.tierProgress = 100;
        }
    }


    // =========================================================
    // HELPERS
    // =========================================================

    private static Contact getCurrentContact() {

        Id contactId;

        if (Test.isRunningTest() && testContactId != null) {

            contactId = testContactId;

        } else {

            User currentUser = [
                SELECT ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            contactId = currentUser.ContactId;
        }

        if (contactId == null) {
            fail('Please sign in to view your account.');
        }

        return [
            SELECT Id,
                   FirstName,
                   LastName,
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