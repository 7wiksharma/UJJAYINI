public without sharing class UJJAYINIHeaderController {

    public class HeaderInfo {

        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Integer cartCount;
    }


    /*
     * Name and cart size for the signed-in customer.
     * Not cacheable, so the badge is always current.
     */
    @AuraEnabled
    public static HeaderInfo getHeaderInfo() {

        HeaderInfo info = new HeaderInfo();

        info.cartCount = 0;

        User currentUser = [
            SELECT FirstName,
                   LastName,
                   ContactId,
                   Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        info.firstName = currentUser.FirstName;
        info.lastName = currentUser.LastName;

        if (
            currentUser.ContactId == null ||
            currentUser.Contact.AccountId == null
        ) {
            return info;
        }

        List<Order> drafts = [
            SELECT Id
            FROM Order
            WHERE AccountId = :currentUser.Contact.AccountId
            AND Status = 'Draft'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (drafts.isEmpty()) {
            return info;
        }

        AggregateResult totals = [
            SELECT SUM(Quantity) quantity
            FROM OrderItem
            WHERE OrderId = :drafts[0].Id
            WITH SYSTEM_MODE
        ];

        Decimal quantity = (Decimal) totals.get('quantity');

        info.cartCount = quantity == null ? 0 : quantity.intValue();

        return info;
    }
}