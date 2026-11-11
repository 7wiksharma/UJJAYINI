import { LightningElement, wire } from 'lwc';

import getCurrentCart from '@salesforce/apex/UJJAYINICartController.getCurrentCart';
import addToCart from '@salesforce/apex/UJJAYINICartController.addToCart';
import decreaseQuantity from '@salesforce/apex/UJJAYINICartController.decreaseQuantity';
import removeFromCart from '@salesforce/apex/UJJAYINICartController.removeFromCart';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class UjjayiniCart extends LightningElement {
    cart;
    isLoading = true;
    errorMessage;

    @wire(getCurrentCart)
    wiredCart({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.cart = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.cart = undefined;
            this.errorMessage = this.getErrorMessage(error);
        }
    }

    get hasItems() {
        return (
            this.cart &&
            this.cart.items &&
            this.cart.items.length > 0
        );
    }

    get isEmpty() {
        return !this.isLoading && !this.hasItems;
    }

    get cartItems() {
        if (!this.cart || !this.cart.items) {
            return [];
        }

        return this.cart.items.map(item => ({
            ...item,
            isMinimumQuantity: item.quantity <= 1
        }));
    }

    async handleIncrease(event) {
        const productId = event.currentTarget.dataset.productId;

        await this.addProduct(productId, 1);
    }

    async handleDecrease(event) {
        const productId = event.currentTarget.dataset.productId;

        this.isLoading = true;

        try {
            this.cart = await decreaseQuantity({
                productId: productId
            });

            this.errorMessage = undefined;

            this.showToast(
                'Cart Updated',
                'Quantity decreased successfully.',
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

    async handleRemove(event) {
        const productId = event.currentTarget.dataset.productId;

        this.isLoading = true;

        try {
            this.cart = await removeFromCart({
                productId: productId
            });

            this.errorMessage = undefined;

            this.showToast(
                'Item Removed',
                'Product removed from your cart.',
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

    async addProduct(productId, quantity) {
        this.isLoading = true;

        try {
            this.cart = await addToCart({
                productId: productId,
                quantity: quantity
            });

            this.errorMessage = undefined;

            this.showToast(
                'Cart Updated',
                'Cart updated successfully.',
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

    handleCheckout() {
        this.showToast(
            'Checkout',
            'Checkout functionality will be connected next.',
            'info'
        );
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Something went wrong.';
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