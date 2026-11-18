import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

import isGuestUser from '@salesforce/user/isGuest';

import createPaymentLink from '@salesforce/apex/UJJAYINIPaymentLinkController.createPaymentLink';
import getCurrentCart from '@salesforce/apex/UJJAYINICartController.getCurrentCart';
import addToCart from '@salesforce/apex/UJJAYINICartController.addToCart';
import decreaseQuantity from '@salesforce/apex/UJJAYINICartController.decreaseQuantity';
import removeFromCart from '@salesforce/apex/UJJAYINICartController.removeFromCart';


export default class UjjayiniCart
    extends NavigationMixin(LightningElement) {


    // =========================================================
    // STATE
    // =========================================================

    cart;

    isLoading = true;

    isUpdating = false;

    isProcessingPayment = false;

    errorMessage;

    wiredCartResult;

    // Notification
    showNotification = false;
    notificationType = '';
    notificationTitle = '';
    notificationMessage = '';
    notificationTimer;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        // Cart is for logged-in customers only.
        if (isGuestUser) {

            const startUrl =
                window.location.pathname +
                window.location.search;

            window.location.href =
                '/ujjayini/login?startURL=' +
                encodeURIComponent(startUrl);

            return;
        }

        // Coming back from the payment page with the browser's
        // Back button must not leave the checkout button disabled.
        window.addEventListener(
            'pageshow',
            this.handlePageShow
        );

    }


    disconnectedCallback() {

        window.removeEventListener(
            'pageshow',
            this.handlePageShow
        );

        if (this.notificationTimer) {
            clearTimeout(this.notificationTimer);
        }

    }


    handlePageShow = event => {

        if (event.persisted) {

            this.isProcessingPayment = false;

            this.refreshCart();

        }

    };


    // =========================================================
    // LOAD CART
    // =========================================================

    @wire(getCurrentCart)
    wiredCart(result) {

        this.wiredCartResult = result;

        const { data, error } = result;

        if (isGuestUser) {
            return;
        }

        if (data) {

            this.cart = data;
            this.errorMessage = undefined;
            this.isLoading = false;

        } else if (error) {

            this.cart = undefined;
            this.errorMessage = this.getErrorMessage(error);
            this.isLoading = false;

        }

    }


    async refreshCart() {

        if (!this.wiredCartResult) {
            return;
        }

        try {
            await refreshApex(this.wiredCartResult);
        } catch (error) {
            // The latest cart was already set from the mutation result.
        }

    }


    handleRetry() {

        this.isLoading = true;

        this.errorMessage = undefined;

        this.refreshCart().then(() => {
            this.isLoading = false;
        });

    }


    // =========================================================
    // VIEW STATES
    // =========================================================

    get showLoader() {

        return isGuestUser || this.isLoading;

    }


    get loaderText() {

        return isGuestUser
            ? 'TAKING YOU TO SIGN IN'
            : 'OPENING YOUR COLLECTION';

    }


    get showError() {

        return (
            !isGuestUser &&
            !this.isLoading &&
            !!this.errorMessage &&
            !this.hasItems
        );

    }


    get hasItems() {

        return !!(
            this.cart &&
            this.cart.items &&
            this.cart.items.length > 0
        );

    }


    get isEmpty() {

        return (
            !isGuestUser &&
            !this.isLoading &&
            !this.errorMessage &&
            !this.hasItems
        );

    }


    get itemsClass() {

        return this.isUpdating
            ? 'cart-items is-updating'
            : 'cart-items';

    }


    // =========================================================
    // DERIVED VALUES
    // =========================================================

    formatPrice(value) {

        if (value === null || value === undefined) {
            return '';
        }

        return new Intl.NumberFormat(
            'en-IN',
            {
                style: 'currency',
                currency: 'INR',
                minimumFractionDigits: 0,
                maximumFractionDigits: 2
            }
        ).format(Number(value));

    }


    get cartItems() {

        if (!this.cart || !this.cart.items) {
            return [];
        }

        return this.cart.items.map(item => {

            const quantity = Number(item.quantity);

            return {
                ...item,
                quantityNumber: quantity,
                formattedUnitPrice: this.formatPrice(item.unitPrice),
                formattedTotal: this.formatPrice(item.totalPrice),
                disableDecrease: this.isUpdating || quantity <= 1
            };

        });

    }


    get itemCountLabel() {

        if (!this.cart || !this.cart.items) {
            return '';
        }

        const count = this.cart.items.reduce(
            (sum, item) => sum + Number(item.quantity || 0),
            0
        );

        return count === 1
            ? '1 TIMEPIECE'
            : count + ' TIMEPIECES';

    }


    get formattedTotal() {

        return this.cart
            ? this.formatPrice(this.cart.totalAmount)
            : '';

    }


    get disableCheckout() {

        return this.isUpdating || this.isProcessingPayment;

    }


    get checkoutLabel() {

        return this.isProcessingPayment
            ? 'OPENING SECURE PAYMENT'
            : 'PROCEED TO PAYMENT';

    }


    // =========================================================
    // QUANTITY / REMOVE
    // =========================================================

    async handleIncrease(event) {

        const productId =
            event.currentTarget.dataset.productId;

        await this.updateCart(
            () => addToCart({
                productId,
                quantity: 1
            }),
            'CART UPDATED',
            'The quantity has been updated.'
        );

    }


    async handleDecrease(event) {

        const productId =
            event.currentTarget.dataset.productId;

        await this.updateCart(
            () => decreaseQuantity({ productId }),
            'CART UPDATED',
            'The quantity has been updated.'
        );

    }


    async handleRemove(event) {

        const productId =
            event.currentTarget.dataset.productId;

        await this.updateCart(
            () => removeFromCart({ productId }),
            'REMOVED FROM CART',
            'The timepiece has been removed from your collection.'
        );

    }


    async updateCart(action, successTitle, successMessage) {

        if (this.isUpdating) {
            return;
        }

        this.isUpdating = true;

        try {

            this.cart = await action();

            this.errorMessage = undefined;

            this.showNotificationPopup(
                'success',
                successTitle,
                successMessage
            );

            // Keep the wire cache in step with the server.
            this.refreshCart();

        } catch (error) {

            this.showNotificationPopup(
                'error',
                'UNABLE TO UPDATE',
                this.getErrorMessage(error)
            );

        } finally {

            this.isUpdating = false;

        }

    }


    // =========================================================
    // CHECKOUT (Razorpay Payment Link)
    // =========================================================

    async handleCheckout() {

        if (
            !this.cart ||
            !this.cart.orderId ||
            this.isProcessingPayment
        ) {
            return;
        }

        this.isProcessingPayment = true;

        try {

            const result =
                await createPaymentLink({
                    orderId: this.cart.orderId
                });

            if (!result || !result.paymentUrl) {

                throw new Error(
                    'Razorpay Payment Link URL was not returned by Salesforce.'
                );

            }

            // Redirect to the Razorpay hosted payment page.
            window.location.href = result.paymentUrl;

        } catch (error) {

            this.isProcessingPayment = false;

            this.showNotificationPopup(
                'error',
                'CHECKOUT ERROR',
                this.getErrorMessage(error)
            );

        }

    }


    // =========================================================
    // NAVIGATION
    // =========================================================

    goToWatches() {

        window.location.href = '/ujjayini/watches';

    }


    handleViewProduct(event) {

        const productId =
            event.currentTarget.dataset.productId;

        if (!productId) {
            return;
        }

        this[NavigationMixin.Navigate]({

            type: 'comm__namedPage',

            attributes: {
                name: 'Product_Detail__c'
            },

            state: {
                productId
            }

        });

    }


    // =========================================================
    // NOTIFICATION
    // =========================================================

    showNotificationPopup(type, title, message) {

        if (this.notificationTimer) {
            clearTimeout(this.notificationTimer);
        }

        this.notificationType = type;

        this.notificationTitle = title;

        this.notificationMessage = message;

        this.showNotification = true;

        this.notificationTimer =
            setTimeout(() => {

                this.showNotification = false;

            }, 4000);

    }


    closeNotification() {

        this.showNotification = false;

        if (this.notificationTimer) {

            clearTimeout(this.notificationTimer);

            this.notificationTimer = null;

        }

    }


    get notificationClass() {

        return this.notificationType === 'error'
            ? 'notification error'
            : 'notification success';

    }


    // =========================================================
    // ERROR
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

        return 'Something went wrong.';

    }

}