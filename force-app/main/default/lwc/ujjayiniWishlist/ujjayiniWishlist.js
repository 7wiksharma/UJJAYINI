import {
    LightningElement,
    wire
} from 'lwc';

import getWishlistItems
    from '@salesforce/apex/UJJAYINIWishlistController.getWishlistItems';

import removeFromWishlist
    from '@salesforce/apex/UJJAYINIWishlistController.removeFromWishlist';

import addToCart
    from '@salesforce/apex/UJJAYINICartController.addToCart';

import isGuestUser
    from '@salesforce/user/isGuest';

import { ShowToastEvent }
    from 'lightning/platformShowToastEvent';

import wishlistCat from '@salesforce/resourceUrl/UJJAYINI_Wishlist_Cat';


export default class UjjayiniWishlist extends LightningElement {

    // =========================================================
    // STATE
    // =========================================================

    wishlistItems = [];

    isLoading = true;

    errorMessage;

    processingProductId;

    // Background image
    backgroundImageUrl = wishlistCat;


    // =========================================================
    // LOAD WISHLIST
    // =========================================================

    @wire(getWishlistItems)
    wiredWishlist({
        data,
        error
    }) {

        this.isLoading = false;


        if (data) {

            this.wishlistItems =
                data.map(item => {

                    return {
                        ...item,

                        formattedPrice:
                            this.formatPrice(
                                item.price
                            ),

                        hasPrice:
                            item.price !== null &&
                            item.price !== undefined,

                        hasCollection:
                            !!item.collectionName,

                        hasImage:
                            !!item.productImageUrl
                    };
                });


            this.errorMessage =
                undefined;

        } else if (error) {

            this.wishlistItems = [];

            this.errorMessage =
                this.getErrorMessage(
                    error
                );
        }
    }


    // =========================================================
    // GETTERS
    // =========================================================

    get hasItems() {

        return (
            this.wishlistItems.length > 0
        );
    }


    get isEmpty() {

        return (
            !this.isLoading &&
            !this.errorMessage &&
            !this.hasItems
        );
    }


    get itemCountLabel() {

        const count =
            this.wishlistItems.length;

        if (count === 1) {
            return '01 TIMEPIECE SAVED';
        }

        return (
            String(count).padStart(2, '0') +
            ' TIMEPIECES SAVED'
        );
    }


    get backgroundStyle() {

        return `
            background-image:
            linear-gradient(
                90deg,
                rgba(5, 6, 10, 0.96) 0%,
                rgba(5, 6, 10, 0.78) 42%,
                rgba(5, 6, 10, 0.55) 72%,
                rgba(5, 6, 10, 0.82) 100%
            ),
            linear-gradient(
                180deg,
                rgba(5, 6, 10, 0.30) 0%,
                rgba(5, 6, 10, 0.55) 55%,
                rgba(5, 6, 10, 0.96) 100%
            ),
            url("${this.backgroundImageUrl}");
        `;
    }


    // =========================================================
    // FORMAT PRICE
    // =========================================================

    formatPrice(price) {

        if (
            price === null ||
            price === undefined
        ) {

            return 'PRICE UNAVAILABLE';
        }


        return new Intl.NumberFormat(
            'en-IN',
            {
                style: 'currency',
                currency: 'INR',
                maximumFractionDigits: 0
            }
        ).format(price);
    }


    // =========================================================
    // REMOVE FROM WISHLIST
    // =========================================================

    async handleRemove(event) {

        const productId =
            event.currentTarget.dataset.productId;


        if (!productId) {
            return;
        }


        this.processingProductId =
            productId;


        try {

            await removeFromWishlist({
                productId
            });


            this.wishlistItems =
                this.wishlistItems.filter(
                    item =>
                        item.productId !== productId
                );


            this.showToast(
                'REMOVED',
                'The timepiece has been removed from your wishlist.',
                'success'
            );

        } catch (error) {

            this.showToast(
                'UNABLE TO REMOVE',
                this.getErrorMessage(error),
                'error'
            );

        } finally {

            this.processingProductId =
                undefined;
        }
    }


    // =========================================================
    // ADD TO CART
    // =========================================================

    async handleAddToCart(event) {

        const productId =
            event.currentTarget.dataset.productId;


        if (!productId) {
            return;
        }


        if (isGuestUser) {

            this.showToast(
                'SIGN IN REQUIRED',
                'Please sign in to add a watch to your cart.',
                'warning'
            );

            return;
        }


        this.processingProductId =
            productId;


        try {

            await addToCart({
                productId,
                quantity: 1
            });


            this.showToast(
                'ADDED TO CART',
                'The timepiece has been added to your cart.',
                'success'
            );

        } catch (error) {

            this.showToast(
                'UNABLE TO ADD',
                this.getErrorMessage(error),
                'error'
            );

        } finally {

            this.processingProductId =
                undefined;
        }
    }


    // =========================================================
    // PRODUCT DETAIL
    // =========================================================

    handleViewProduct(event) {

        const productId =
            event.currentTarget.dataset.productId;


        if (!productId) {
            return;
        }


        window.location.href =
            '/ujjayini/product-detail?productId=' +
            encodeURIComponent(
                productId
            );
    }


    // =========================================================
    // BACK TO COLLECTION
    // =========================================================

    handleBrowseCollection() {

        window.location.href =
            '/ujjayini/watches';
    }


    // =========================================================
    // PROCESSING CHECK
    // =========================================================

    isProcessing(productId) {

        return (
            this.processingProductId ===
            productId
        );
    }


    // =========================================================
    // ERROR HANDLING
    // =========================================================

    getErrorMessage(error) {

        if (
            error &&
            error.body &&
            error.body.message
        ) {

            return error.body.message;
        }


        if (
            error &&
            error.message
        ) {

            return error.message;
        }


        return (
            'Unable to load your wishlist.'
        );
    }


    // =========================================================
    // TOAST
    // =========================================================

    showToast(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}