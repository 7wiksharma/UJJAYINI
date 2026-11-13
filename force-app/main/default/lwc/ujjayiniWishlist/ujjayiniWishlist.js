import { LightningElement, wire } from 'lwc';

import getWishlistItems from '@salesforce/apex/UJJAYINIWishlistController.getWishlistItems';
import removeFromWishlist from '@salesforce/apex/UJJAYINIWishlistController.removeFromWishlist';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class UjjayiniWishlist extends LightningElement {

    wishlistItems = [];
    isLoading = true;
    errorMessage;

    @wire(getWishlistItems)
    wiredWishlist({ data, error }) {

        this.isLoading = false;

        if (data) {

            this.wishlistItems =
                data.map(item => ({
                    ...item
                }));

            this.errorMessage = undefined;

        } else if (error) {

            this.wishlistItems = [];

            this.errorMessage =
                this.getErrorMessage(error);
        }
    }

    get hasItems() {
        return this.wishlistItems.length > 0;
    }

    get isEmpty() {
        return !this.isLoading &&
               !this.errorMessage &&
               this.wishlistItems.length === 0;
    }

    async handleRemove(event) {

        const productId =
            event.currentTarget.dataset.productId;

        if (!productId) {
            return;
        }

        this.isLoading = true;

        try {

            await removeFromWishlist({
                productId
            });

            this.wishlistItems =
                this.wishlistItems.filter(
                    item => item.productId !== productId
                );

            this.showToast(
                'Removed',
                'Watch removed from your wishlist.',
                'success'
            );

        } catch (error) {

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );

        } finally {

            this.isLoading = false;
        }
    }

    getErrorMessage(error) {

        if (
            error &&
            error.body &&
            error.body.message
        ) {
            return error.body.message;
        }

        return 'Unable to load your wishlist.';
    }

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}