public without sharing class WishlistService {

    public class WishlistResult {
        @AuraEnabled public Id wishlistId;
        @AuraEnabled public Integer itemCount;
    }

    public class WishlistItemResult {
        @AuraEnabled public Id wishlistItemId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productImageUrl;
        @AuraEnabled public Decimal price;
        @AuraEnabled public String collectionName;

        // Specifications for the comparison drawer
        @AuraEnabled public String movement;
        @AuraEnabled public String caseMaterial;
        @AuraEnabled public String dialColor;
        @AuraEnabled public String modelNumber;
        @AuraEnabled public String productCode;
    }


    // =========================================================
    // GET OR CREATE WISHLIST
    // =========================================================

    public static Id getOrCreateWishlist() {

        Id contactId = currentContactId();

        if (contactId == null) {
            throw new IllegalArgumentException(
                'Please sign in to use your wishlist.'
            );
        }

        List<Wishlist__c> existing = [
            SELECT Id
            FROM Wishlist__c
            WHERE Contact__c = :contactId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Wishlist__c wishlist = new Wishlist__c(Contact__c = contactId);

        Database.insert(wishlist, AccessLevel.SYSTEM_MODE);

        return wishlist.Id;
    }


    // =========================================================
    // ADD
    // =========================================================

    public static Id addToWishlist(Id productId) {

        if (productId == null) {
            throw new IllegalArgumentException('Product Id is required.');
        }

        Id wishlistId = getOrCreateWishlist();

        List<Wishlist_Item__c> existing = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Wishlist__c = :wishlistId
            AND Product__c = :productId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Wishlist_Item__c item = new Wishlist_Item__c(
            Wishlist__c = wishlistId,
            Product__c = productId
        );

        Database.insert(item, AccessLevel.SYSTEM_MODE);

        return item.Id;
    }


    // =========================================================
    // REMOVE (all copies of the product, so it cannot come back)
    // =========================================================

    public static void removeFromWishlist(Id productId) {

        if (productId == null) {
            throw new IllegalArgumentException('Product Id is required.');
        }

        Id wishlistId = getOrCreateWishlist();

        List<Wishlist_Item__c> items = [
            SELECT Id
            FROM Wishlist_Item__c
            WHERE Wishlist__c = :wishlistId
            AND Product__c = :productId
            WITH SYSTEM_MODE
        ];

        if (!items.isEmpty()) {
            Database.delete(items, AccessLevel.SYSTEM_MODE);
        }
    }


    // =========================================================
    // GET ITEMS
    // =========================================================

    public static List<WishlistItemResult> getWishlistItems() {

        List<WishlistItemResult> results = new List<WishlistItemResult>();

        Id contactId = currentContactId();

        if (contactId == null) {
            return results;
        }

        List<Wishlist__c> wishlists = [
            SELECT Id
            FROM Wishlist__c
            WHERE Contact__c = :contactId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (wishlists.isEmpty()) {
            return results;
        }

        List<Wishlist_Item__c> items = [
            SELECT Id,
                   Product__c,
                   Product__r.Name,
                   Product__r.ProductCode,
                   Product__r.Product_Image_URL__c,
                   Product__r.Collection__r.Name,
                   Product__r.Movement_Type__c,
                   Product__r.Case_Material__c,
                   Product__r.Dial_Color__c,
                   Product__r.Model_Number__c
            FROM Wishlist_Item__c
            WHERE Wishlist__c = :wishlists[0].Id
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
        ];

        Set<Id> productIds = new Set<Id>();

        for (Wishlist_Item__c item : items) {
            if (item.Product__c != null) {
                productIds.add(item.Product__c);
            }
        }

        Map<Id, Decimal> prices = new Map<Id, Decimal>();

        if (!productIds.isEmpty()) {

            for (PricebookEntry entry : [
                SELECT Product2Id, UnitPrice
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                AND IsActive = true
                AND Pricebook2.IsActive = true
                AND Pricebook2.IsStandard = true
                WITH SYSTEM_MODE
            ]) {
                if (!prices.containsKey(entry.Product2Id)) {
                    prices.put(entry.Product2Id, entry.UnitPrice);
                }
            }
        }

        // One card per product, even if an old duplicate row exists.
        Set<Id> seen = new Set<Id>();

        for (Wishlist_Item__c item : items) {

            if (item.Product__c == null || seen.contains(item.Product__c)) {
                continue;
            }

            seen.add(item.Product__c);

            Product2 product = item.Product__r;

            WishlistItemResult result = new WishlistItemResult();

            result.wishlistItemId = item.Id;
            result.productId = item.Product__c;
            result.productName = product != null ? product.Name : 'UJJAYINI Timepiece';
            result.productImageUrl = product != null ? product.Product_Image_URL__c : null;
            result.collectionName =
                product != null && product.Collection__r != null
                    ? product.Collection__r.Name
                    : null;
            result.price = prices.get(item.Product__c);

            if (product != null) {
                result.movement = product.Movement_Type__c;
                result.caseMaterial = product.Case_Material__c;
                result.dialColor = product.Dial_Color__c;
                result.modelNumber = product.Model_Number__c;
                result.productCode = product.ProductCode;
            }

            results.add(result);
        }

        return results;
    }


    // =========================================================
    // IS WISHLISTED
    // =========================================================

    public static Boolean isWishlisted(Id productId) {

        Id contactId = currentContactId();

        if (productId == null || contactId == null) {
            return false;
        }

        return [
            SELECT COUNT()
            FROM Wishlist_Item__c
            WHERE Wishlist__r.Contact__c = :contactId
            AND Product__c = :productId
            WITH SYSTEM_MODE
        ] > 0;
    }


    // =========================================================
    // HELPERS
    // =========================================================

    private static Id currentContactId() {

        return [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ].ContactId;
    }
}