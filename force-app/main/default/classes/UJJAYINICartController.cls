public with sharing class UJJAYINICartController {

    @AuraEnabled(cacheable=true)
    public static UJJAYINICartService.CartResult getCurrentCart() {
        try {
            return UJJAYINICartService.getCurrentCart();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static UJJAYINICartService.CartResult addToCart(
        Id productId,
        Integer quantity
    ) {
        try {
            return UJJAYINICartService.addToCart(
                productId,
                quantity
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
public static UJJAYINICartService.CartResult decreaseQuantity(
    Id productId
) {
    try {
        return UJJAYINICartService.decreaseQuantity(
            productId
        );
    } catch (Exception e) {
        throw new AuraHandledException(
            e.getMessage()
        );
    }
}


@AuraEnabled
public static UJJAYINICartService.CartResult removeFromCart(
    Id productId
) {
    try {
        return UJJAYINICartService.removeFromCart(
            productId
        );
    } catch (Exception e) {
        throw new AuraHandledException(
            e.getMessage()
        );
    }
}
}