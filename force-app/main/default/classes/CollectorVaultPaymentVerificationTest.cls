@IsTest
private class CollectorVaultPaymentVerificationTest {

    private static Account createAccount(String name) {

        Account account = new Account(Name = name);

        insert account;

        return account;
    }


    private static Order createOrder(Id accountId) {

        Order orderRecord = new Order(
            AccountId = accountId,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );

        insert orderRecord;

        return orderRecord;
    }


    private static Payment__c createPayment(
        Id orderId,
        String status,
        String paymentLinkId
    ) {

        Payment__c payment = new Payment__c(
            Order__c = orderId,
            Amount__c = 1000,
            Payment_Status__c = status,
            Gateway_Order_ID__c = paymentLinkId
        );

        if (status == 'Captured') {
            payment.Paid_At__c = System.now();
        }

        insert payment;

        return payment;
    }


    private static void createAsset(Id accountId, Id orderId) {

        insert new Asset(
            Name = 'UJJAYINI Test Asset',
            AccountId = accountId,
            Quantity = 1,
            Status = 'Purchased',
            SerialNumber = 'UJJAYINI-' + String.valueOf(orderId)
        );
    }


    @IsTest
    static void capturedPaymentWithAssetIsReady() {

        Account account = createAccount('Vault Owner');
        Order orderRecord = createOrder(account.Id);

        createPayment(orderRecord.Id, 'Captured', 'plink_owner_1');
        createAsset(account.Id, orderRecord.Id);

        CollectorVaultService.testAccountId = account.Id;

        CollectorVaultService.PaymentVerificationResult result =
            CollectorVaultService.verifyPayment('plink_owner_1');

        System.assertEquals('ASSET_READY', result.state);
        System.assertEquals(true, result.paymentConfirmed);
        System.assertEquals(true, result.assetReady);
    }


    @IsTest
    static void capturedPaymentWithoutAssetIsNotReadyYet() {

        Account account = createAccount('Vault Owner');
        Order orderRecord = createOrder(account.Id);

        createPayment(orderRecord.Id, 'Captured', 'plink_owner_2');

        CollectorVaultService.testAccountId = account.Id;

        CollectorVaultService.PaymentVerificationResult result =
            CollectorVaultService.verifyPayment('plink_owner_2');

        System.assertEquals('PAYMENT_CONFIRMED', result.state);
        System.assertEquals(true, result.paymentConfirmed);
        System.assertEquals(false, result.assetReady);
    }


    @IsTest
    static void pendingPaymentIsNotConfirmed() {

        Account account = createAccount('Vault Owner');
        Order orderRecord = createOrder(account.Id);

        createPayment(orderRecord.Id, 'Pending', 'plink_owner_3');

        CollectorVaultService.testAccountId = account.Id;

        CollectorVaultService.PaymentVerificationResult result =
            CollectorVaultService.verifyPayment('plink_owner_3');

        System.assertEquals('PENDING', result.state);
        System.assertEquals(false, result.paymentConfirmed);
        System.assertEquals(false, result.assetReady);
    }


    @IsTest
    static void anotherCustomerCannotVerifyThePayment() {

        Account owner = createAccount('Vault Owner');
        Account stranger = createAccount('Another Customer');

        Order orderRecord = createOrder(owner.Id);

        createPayment(orderRecord.Id, 'Captured', 'plink_owner_4');
        createAsset(owner.Id, orderRecord.Id);

        // Logged in as a DIFFERENT customer.
        CollectorVaultService.testAccountId = stranger.Id;

        CollectorVaultService.PaymentVerificationResult result =
            CollectorVaultService.verifyPayment('plink_owner_4');

        System.assertEquals('NOT_FOUND', result.state);
        System.assertEquals(false, result.paymentConfirmed);
        System.assertEquals(false, result.assetReady);
    }


    @IsTest
    static void blankLinkIdUsesTheLatestOwnPayment() {

        Account account = createAccount('Vault Owner');
        Order orderRecord = createOrder(account.Id);

        createPayment(orderRecord.Id, 'Captured', 'plink_owner_5');
        createAsset(account.Id, orderRecord.Id);

        CollectorVaultService.testAccountId = account.Id;

        CollectorVaultService.PaymentVerificationResult result =
            CollectorVaultService.verifyPayment(null);

        System.assertEquals('ASSET_READY', result.state);
    }


    @IsTest
    static void unknownLinkIdIsNotFound() {

        Account account = createAccount('Vault Owner');

        CollectorVaultService.testAccountId = account.Id;

        CollectorVaultService.PaymentVerificationResult result =
            CollectorVaultService.verifyPayment('plink_does_not_exist');

        System.assertEquals('NOT_FOUND', result.state);
    }


    @IsTest
    static void userWithoutContactGetsNothing() {

        // Running user is an internal admin with no Contact.
        CollectorVaultService.PaymentVerificationResult result =
            CollectorVaultService.verifyPayment('plink_any');

        System.assertEquals('NOT_FOUND', result.state);
        System.assertEquals(false, result.assetReady);
    }


    @IsTest
    static void controllerDelegatesToTheService() {

        Account account = createAccount('Vault Owner');
        Order orderRecord = createOrder(account.Id);

        createPayment(orderRecord.Id, 'Captured', 'plink_owner_6');
        createAsset(account.Id, orderRecord.Id);

        CollectorVaultService.testAccountId = account.Id;

        CollectorVaultService.PaymentVerificationResult result =
            UJJAYINICollectorVaultController.verifyPayment(
                'plink_owner_6'
            );

        System.assertEquals(true, result.assetReady);
    }
}