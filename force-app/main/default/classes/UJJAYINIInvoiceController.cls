public with sharing class UJJAYINIInvoiceController {

    @TestVisible
    private static Id testAccountId;


    public class InvoiceFile {

        @AuraEnabled public String fileName;

        @AuraEnabled public String base64Pdf;
    }


    @AuraEnabled
    public static InvoiceFile getMyInvoice(Id orderId) {

        try {

            if (orderId == null) {
                throw new IllegalArgumentException('Order Id is required.');
            }

            Id accountId = currentAccountId();

            Order orderRecord = OrderInvoiceService.loadOrder(orderId);

            if (accountId == null || orderRecord.AccountId != accountId) {
                throw new IllegalArgumentException('Invoice not found.');
            }

            if (orderRecord.Status == 'Draft') {
                throw new IllegalArgumentException(
                    'Your invoice will be available once your payment is confirmed.'
                );
            }

            InvoiceFile file = new InvoiceFile();

            file.fileName =
                OrderInvoiceService.fileName(orderRecord);

            file.base64Pdf =
                EncodingUtil.base64Encode(
                    OrderInvoiceService.buildInvoicePdf(orderRecord.Id)
                );

            return file;

        } catch (Exception e) {

            throw new AuraHandledException(e.getMessage());
        }
    }


    private static Id currentAccountId() {

        if (Test.isRunningTest() && testAccountId != null) {
            return testAccountId;
        }

        User currentUser = [
            SELECT Id,
                   ContactId,
                   Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return currentUser.ContactId == null
            ? null
            : currentUser.Contact.AccountId;
    }
}