public with sharing class UJJAYINIWishlistController {

    public class WishlistItemResponse {

        @AuraEnabled
        public Id wishlistItemId;

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productName;
    }

    @AuraEnabled
    public static Id addToWishlist(Id productId) {

        if (productId == null) {
            throw new AuraHandledException(
                'Product Id is required.'
            );
        }

        try {

            return WishlistService.addToWishlist(
                productId
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static void removeFromWishlist(Id productId) {

        if (productId == null) {
            throw new AuraHandledException(
                'Product Id is required.'
            );
        }

        try {

            WishlistService.removeFromWishlist(
                productId
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<WishlistItemResponse> getWishlistItems() {

        try {

            List<WishlistService.WishlistItemResult> items =
                WishlistService.getWishlistItems();

            List<WishlistItemResponse> responses =
                new List<WishlistItemResponse>();

            for (
                WishlistService.WishlistItemResult item :
                items
            ) {

                WishlistItemResponse response =
                    new WishlistItemResponse();

                response.wishlistItemId =
                    item.wishlistItemId;

                response.productId =
                    item.productId;

                response.productName =
                    item.productName;

                responses.add(response);
            }

            return responses;

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isWishlisted(Id productId) {

        if (productId == null) {
            return false;
        }

        try {

            return WishlistService.isWishlisted(
                productId
            );

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }
    }
}