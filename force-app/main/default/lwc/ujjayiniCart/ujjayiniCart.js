import { LightningElement, wire } from 'lwc';
import createPaymentLink from '@salesforce/apex/UJJAYINIPaymentLinkController.createPaymentLink';
import getCurrentCart from '@salesforce/apex/UJJAYINICartController.getCurrentCart';
import addToCart from '@salesforce/apex/UJJAYINICartController.addToCart';
import decreaseQuantity from '@salesforce/apex/UJJAYINICartController.decreaseQuantity';
import removeFromCart from '@salesforce/apex/UJJAYINICartController.removeFromCart';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class UjjayiniCart extends LightningElement {

    cart;
    isLoading = true;
    errorMessage;

   

    /*
     * Get current cart.
     */
    @wire(getCurrentCart)
    wiredCart({ data, error }) {

        this.isLoading = false;

        if (data) {

            this.cart = data;
            this.errorMessage = undefined;

        } else if (error) {

            this.cart = undefined;
            this.errorMessage =
                this.getErrorMessage(error);
        }
    }

    /*
     * Check whether cart has items.
     */
    get hasItems() {

        return (
            this.cart &&
            this.cart.items &&
            this.cart.items.length > 0
        );
    }

    /*
     * Check whether cart is empty.
     */
    get isEmpty() {

        return (
            !this.isLoading &&
            !this.hasItems
        );
    }

    /*
     * Prepare cart items for HTML.
     */
    get cartItems() {

        if (!this.cart || !this.cart.items) {
            return [];
        }

        return this.cart.items.map(item => ({
            ...item,
            isMinimumQuantity:
                item.quantity <= 1
        }));
    }

    /*
     * Increase product quantity.
     */
    async handleIncrease(event) {

        const productId =
            event.currentTarget.dataset.productId;

        await this.addProduct(productId, 1);
    }

    /*
     * Decrease product quantity.
     */
    async handleDecrease(event) {

        const productId =
            event.currentTarget.dataset.productId;

        this.isLoading = true;

        try {

            this.cart =
                await decreaseQuantity({
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

    /*
     * Remove product from cart.
     */
    async handleRemove(event) {

        const productId =
            event.currentTarget.dataset.productId;

        this.isLoading = true;

        try {

            this.cart =
                await removeFromCart({
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

    /*
     * Add product to cart.
     */
    async addProduct(productId, quantity) {

        this.isLoading = true;

        try {

            this.cart =
                await addToCart({
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

    /*
     * Main checkout process.
     *
     * 1. Call Salesforce Apex.
     * 2. Apex creates Razorpay Order.
     * 3. Apex creates Payment__c.
     * 4. Apex reserves inventory.
     * 5. Apex returns Razorpay Gateway Order ID.
     * 6. Open Razorpay Checkout.
     */
   async handleCheckout() {

    console.log('UJJAYINI PAYMENT LINK CHECKOUT START');

    if (!this.cart || !this.cart.orderId) {

        this.errorMessage =
            'Your cart is not available for checkout.';

        return;
    }

    this.isLoading = true;
    this.errorMessage = undefined;

    try {

        console.log(
            'CREATING RAZORPAY PAYMENT LINK FOR ORDER:',
            this.cart.orderId
        );

        const result =
            await createPaymentLink({
                orderId: this.cart.orderId
            });

        console.log(
            'PAYMENT LINK RESULT:',
            JSON.stringify(result)
        );

        if (
            !result ||
            !result.paymentUrl
        ) {

            throw new Error(
                'Razorpay Payment Link URL was not returned by Salesforce.'
            );
        }

        this.showToast(
            'Redirecting to Payment',
            'Opening Razorpay secure payment page...',
            'success'
        );

        /*
         * Redirect customer to Razorpay hosted
         * Payment Link page.
         */
        window.location.href =
            result.paymentUrl;

    } catch (error) {

        console.error(
            'PAYMENT LINK CHECKOUT ERROR:',
            error
        );

        const message =
            this.getErrorMessage(error);

        this.errorMessage =
            'CHECKOUT ERROR: ' + message;

        this.showToast(
            'Checkout Error',
            message,
            'error'
        );

    } finally {

        this.isLoading = false;
    }
}

    /*
     * Extract useful error message.
     */
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

        return 'Something went wrong.';
    }

    /*
     * Display toast.
     */
    showToast(
        title,
        message,
        variant
    ) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
