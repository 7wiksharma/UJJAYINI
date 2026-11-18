public without sharing class WishlistService {

    // =========================================================
    // WISHLIST RESULT
    // =========================================================

    public class WishlistResult {

        @AuraEnabled
        public Id wishlistId;

        @AuraEnabled
        public Integer itemCount;
    }


    // =========================================================
    // WISHLIST ITEM RESULT
    // =========================================================

    public class WishlistItemResult {

        @AuraEnabled
        public Id wishlistItemId;

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String productImageUrl;

        @AuraEnabled
        public Decimal price;

        @AuraEnabled
        public String collectionName;
    }


    // =========================================================
    // GET OR CREATE WISHLIST
    // =========================================================

    /*
     * Get the Wishlist belonging to the currently logged-in
     * Experience Cloud customer.
     */
    public static Id getOrCreateWishlist() {

        User currentUser = [
            SELECT Id,
                   ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (currentUser.ContactId == null) {

            throw new IllegalArgumentException(
                'The current user is not associated with a Contact.'
            );
        }


        List<Wishlist__c> existingWishlists = [
            SELECT Id
            FROM Wishlist__c
            WHERE Contact__c = :currentUser.ContactId
            WITH SYSTEM_MODE
            LIMIT 1
        ];


        if (!existingWishlists.isEmpty()) {

            return existingWishlists[0].Id;
        }


        Wishlist__c wishlist =
            new Wishlist__c(
                Contact__c = currentUser.ContactId
            );


        Database.insert(
            wishlist,
            AccessLevel.SYSTEM_MODE
        );


        return wishlist.Id;
    }


    // =========================================================
    // ADD TO WISHLIST
    // =========================================================

    /*
     * Add a Product to the customer's Wishlist.
     */
    public static Id addToWishlist(
        Id productId
    ) {

        if (productId == null) {

            throw new IllegalArgumentException(
                'Product Id is required.'
            );
        }


        Id wishlistId =
            getOrCreateWishlist();


        List<Wishlist_Item__c> existingItems = [

            SELECT Id
            FROM Wishlist_Item__c
            WHERE Wishlist__c = :wishlistId
            AND Product__c = :productId
            WITH SYSTEM_MODE
            LIMIT 1

        ];


        if (!existingItems.isEmpty()) {

            return existingItems[0].Id;
        }


        Wishlist_Item__c item =
            new Wishlist_Item__c(
                Wishlist__c = wishlistId,
                Product__c = productId
            );


        Database.insert(
            item,
            AccessLevel.SYSTEM_MODE
        );


        return item.Id;
    }


    // =========================================================
    // REMOVE FROM WISHLIST
    // =========================================================

    /*
     * Remove a Product from the customer's Wishlist.
     */
    public static void removeFromWishlist(
        Id productId
    ) {

        if (productId == null) {

            throw new IllegalArgumentException(
                'Product Id is required.'
            );
        }


        Id wishlistId =
            getOrCreateWishlist();


        List<Wishlist_Item__c> items = [

            SELECT Id
            FROM Wishlist_Item__c
            WHERE Wishlist__c = :wishlistId
            AND Product__c = :productId
            WITH SYSTEM_MODE

        ];


        if (!items.isEmpty()) {

            Database.delete(
                items,
                AccessLevel.SYSTEM_MODE
            );
        }
    }


    // =========================================================
    // GET WISHLIST ITEMS
    // =========================================================

    /*
     * Return all products in the customer's Wishlist.
     *
     * Additional product information is returned for the
     * UJJAYINI Wishlist UI:
     *
     * - Product Name
     * - Product Image
     * - Standard Price
     * - Collection Name
     */
    public static List<WishlistItemResult> getWishlistItems() {

        User currentUser = [
            SELECT Id,
                   ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];


        if (currentUser.ContactId == null) {

            return new List<WishlistItemResult>();
        }


        // -----------------------------------------------------
        // FIND CUSTOMER WISHLIST
        // -----------------------------------------------------

        List<Wishlist__c> wishlists = [

            SELECT Id
            FROM Wishlist__c
            WHERE Contact__c = :currentUser.ContactId
            WITH SYSTEM_MODE
            LIMIT 1

        ];


        if (wishlists.isEmpty()) {

            return new List<WishlistItemResult>();
        }


        Id wishlistId =
            wishlists[0].Id;


        // -----------------------------------------------------
        // GET WISHLIST ITEMS
        // -----------------------------------------------------

        List<Wishlist_Item__c> items = [

            SELECT Id,
                   Product__c,
                   Product__r.Name,
                   Product__r.Product_Image_URL__c,
                   Product__r.Collection__r.Name
            FROM Wishlist_Item__c
            WHERE Wishlist__c = :wishlistId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC

        ];


        // -----------------------------------------------------
        // COLLECT PRODUCT IDS
        // -----------------------------------------------------

        Set<Id> productIds =
            new Set<Id>();


        for (Wishlist_Item__c item : items) {

            if (item.Product__c != null) {

                productIds.add(
                    item.Product__c
                );
            }
        }


        // -----------------------------------------------------
        // GET STANDARD PRICEBOOK
        // -----------------------------------------------------

        Map<Id, Decimal> productPrices =
            new Map<Id, Decimal>();


        if (!productIds.isEmpty()) {

            List<PricebookEntry> priceEntries = [

                SELECT Product2Id,
                       UnitPrice
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                AND IsActive = true
                AND Pricebook2.IsActive = true
                AND Pricebook2.IsStandard = true
                WITH SYSTEM_MODE

            ];


            for (
                PricebookEntry entry :
                priceEntries
            ) {

                if (
                    !productPrices.containsKey(
                        entry.Product2Id
                    )
                ) {

                    productPrices.put(
                        entry.Product2Id,
                        entry.UnitPrice
                    );
                }
            }
        }


        // -----------------------------------------------------
        // BUILD RESPONSE
        // -----------------------------------------------------

        List<WishlistItemResult> results =
            new List<WishlistItemResult>();


        for (
            Wishlist_Item__c item :
            items
        ) {

            WishlistItemResult result =
                new WishlistItemResult();


            result.wishlistItemId =
                item.Id;


            result.productId =
                item.Product__c;


            result.productName =
                item.Product__r != null
                    ? item.Product__r.Name
                    : 'UJJAYINI Watch';


            result.productImageUrl =
                item.Product__r != null
                    ? item.Product__r.Product_Image_URL__c
                    : null;


            result.collectionName =
                (
                    item.Product__r != null &&
                    item.Product__r.Collection__r != null
                )
                    ? item.Product__r.Collection__r.Name
                    : null;


            result.price =
                productPrices.containsKey(
                    item.Product__c
                )
                    ? productPrices.get(
                        item.Product__c
                    )
                    : null;


            results.add(result);
        }


        return results;
    }


    // =========================================================
    // CHECK IF PRODUCT IS WISHLISTED
    // =========================================================

    public static Boolean isWishlisted(
        Id productId
    ) {

        if (productId == null) {

            return false;
        }


        User currentUser = [

            SELECT Id,
                   ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1

        ];


        if (currentUser.ContactId == null) {

            return false;
        }


        List<Wishlist__c> wishlists = [

            SELECT Id
            FROM Wishlist__c
            WHERE Contact__c = :currentUser.ContactId
            WITH SYSTEM_MODE
            LIMIT 1

        ];


        if (wishlists.isEmpty()) {

            return false;
        }


        List<Wishlist_Item__c> items = [

            SELECT Id
            FROM Wishlist_Item__c
            WHERE Wishlist__c = :wishlists[0].Id
            AND Product__c = :productId
            WITH SYSTEM_MODE
            LIMIT 1

        ];


        return !items.isEmpty();
    }
}