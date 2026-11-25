@IsTest
private class UJJAYINICheckoutAddressControllerTest {

    private static Contact createCustomerWithCart(Boolean withCart) {

        Account account = new Account(
            Name = 'Checkout Test Household'
        );

        insert account;

        Contact contact = new Contact(
            LastName = 'Collector',
            Email = 'collector@example.com',
            AccountId = account.Id
        );

        insert contact;

        if (withCart) {

            insert new Order(
                AccountId = account.Id,
                EffectiveDate = Date.today(),
                Status = 'Draft'
            );
        }

        return contact;
    }


    @IsTest
    static void addressIsSavedOnTheCart() {

        Contact customer = createCustomerWithCart(true);

        UJJAYINICheckoutAddressController.testContactId = customer.Id;

        UJJAYINICheckoutAddressController.CheckoutAddress saved =
            UJJAYINICheckoutAddressController.saveShippingAddress(
                '9876543210',
                '12 Mahakal Marg',
                'Near Ram Ghat',
                'Ujjain',
                'Madhya Pradesh',
                '456001',
                'India'
            );

        System.assertEquals(true, saved.isSavedOnOrder);
        System.assertEquals('12 Mahakal Marg', saved.line1);
        System.assertEquals('Near Ram Ghat', saved.line2);

        Order cart = [
            SELECT ShippingCity,
                   ShippingPostalCode,
                   BillingCity,
                   ShipToContactId
            FROM Order
            WHERE AccountId = :customer.AccountId
        ];

        System.assertEquals('Ujjain', cart.ShippingCity);
        System.assertEquals('456001', cart.ShippingPostalCode);
        System.assertEquals('Ujjain', cart.BillingCity);
        System.assertEquals(customer.Id, cart.ShipToContactId);

        Contact updated = [
            SELECT Phone
            FROM Contact
            WHERE Id = :customer.Id
        ];

        System.assertEquals('9876543210', updated.Phone);
    }


    @IsTest
    static void invalidPinCodeIsRejected() {

        Contact customer = createCustomerWithCart(true);

        UJJAYINICheckoutAddressController.testContactId = customer.Id;

        Boolean rejected = false;

        try {

            UJJAYINICheckoutAddressController.saveShippingAddress(
                '9876543210',
                '12 Mahakal Marg',
                null,
                'Ujjain',
                'Madhya Pradesh',
                '45',
                'India'
            );

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('PIN code'));
        }

        System.assertEquals(true, rejected);
    }


    @IsTest
    static void emptyCartIsRejected() {

        Contact customer = createCustomerWithCart(false);

        UJJAYINICheckoutAddressController.testContactId = customer.Id;

        Boolean rejected = false;

        try {

            UJJAYINICheckoutAddressController.saveShippingAddress(
                '9876543210',
                '12 Mahakal Marg',
                null,
                'Ujjain',
                'Madhya Pradesh',
                '456001',
                'India'
            );

        } catch (AuraHandledException e) {

            rejected = true;

            System.assert(e.getMessage().contains('cart is empty'));
        }

        System.assertEquals(true, rejected);
    }


    @IsTest
    static void prefillReturnsTheCustomer() {

        Contact customer = createCustomerWithCart(true);

        UJJAYINICheckoutAddressController.testContactId = customer.Id;

        UJJAYINICheckoutAddressController.CheckoutAddress address =
            UJJAYINICheckoutAddressController.getCheckoutAddress();

        System.assertEquals('collector@example.com', address.email);
        System.assertEquals(false, address.isSavedOnOrder);
        System.assertEquals('India', address.country);
    }

    @IsTest
    static void shortStateNamesAreConverted() {

        // "mp", "M.P" and the full name all become the state Salesforce accepts.
        String fromShort = UJJAYINICheckoutAddressController.indianStateName('mp');
        String fromDots = UJJAYINICheckoutAddressController.indianStateName('M.P');
        String fromFull = UJJAYINICheckoutAddressController.indianStateName('madhya pradesh');

        System.assert(fromShort != null && fromShort.containsIgnoreCase('Madhya'));
        System.assertEquals(fromShort, fromDots);
        System.assertEquals(fromShort, fromFull);

        // Something that is not an Indian state is not accepted.
        System.assertEquals(null, UJJAYINICheckoutAddressController.indianStateName('Gotham'));
    }
}