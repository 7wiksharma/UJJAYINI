import {
    LightningElement,
    wire
} from 'lwc';

import {
    CurrentPageReference
} from 'lightning/navigation';

import isGuestUser
    from '@salesforce/user/isGuest';

import getProduct
    from '@salesforce/apex/UJJAYINIProductCatalogController.getProduct';

import addToCart
    from '@salesforce/apex/UJJAYINICartController.addToCart';

import productVideo
    from '@salesforce/resourceUrl/UJJAYINI_Product_Detail_Video';


export default class UjjayiniProductDetail
    extends LightningElement {


    // =========================================================
    // STATE
    // =========================================================

    productId;

    product;

    isLoading = true;

    errorMessage;

    isAddingToCart = false;


    // Notification
    showNotification = false;

    notificationType = '';

    notificationTitle = '';

    notificationMessage = '';

    notificationTimer;


    // Guest modal
    showGuestCartModal = false;


    // Video
    videoUrl = productVideo;

    videoInitialized = false;


    // =========================================================
    // PAGE REFERENCE
    // =========================================================

    @wire(CurrentPageReference)
    getPageReference(pageReference) {

        if (
            pageReference &&
            pageReference.state
        ) {

            const productId =
                pageReference.state.productId ||
                pageReference.state.c__productId;


            if (
                productId &&
                productId !== this.productId
            ) {

                this.productId =
                    productId;

                this.loadProduct();

            }

        }

    }


    // =========================================================
    // LIFECYCLE
    // =========================================================

    renderedCallback() {

        if (this.videoInitialized) {
            return;
        }


        const video =
            this.template.querySelector(
                '.product-video'
            );


        if (!video) {
            return;
        }


        this.videoInitialized = true;


        video.muted = true;

        video.defaultMuted = true;

        video.playsInline = true;


        const reduceMotion =
            window.matchMedia &&
            window.matchMedia(
                '(prefers-reduced-motion: reduce)'
            ).matches;


        if (reduceMotion) {

            video.pause();

            return;

        }


        const playPromise =
            video.play();


        if (
            playPromise &&
            playPromise.catch
        ) {

            playPromise.catch(() => {

                // Browser autoplay policy.
                // Poster/background remains visible.

            });

        }

    }


    disconnectedCallback() {

        if (this.notificationTimer) {

            clearTimeout(
                this.notificationTimer
            );

        }

    }


    // =========================================================
    // LOAD PRODUCT
    // =========================================================

    async loadProduct() {

        if (!this.productId) {

            this.isLoading = false;

            this.errorMessage =
                'Product information is missing.';

            return;

        }


        this.isLoading = true;

        this.errorMessage = undefined;


        try {

            this.product =
                await getProduct({
                    productId:
                        this.productId
                });

        }

        catch (error) {

            this.product = undefined;

            this.errorMessage =
                this.getErrorMessage(
                    error
                );

        }

        finally {

            this.isLoading = false;

        }

    }


    // =========================================================
    // DERIVED VALUES
    // =========================================================

    get hasProduct() {

        return !!this.product;

    }


    get formattedPrice() {

        if (
            this.product &&
            this.product.price !== null &&
            this.product.price !== undefined
        ) {

            return new Intl.NumberFormat(
                'en-IN',
                {
                    style: 'currency',
                    currency: 'INR',
                    maximumFractionDigits: 0
                }
            ).format(
                this.product.price
            );

        }


        return 'Price unavailable';

    }


    // =========================================================
    // PRODUCT DETAILS
    // =========================================================

    get specs() {

        if (!this.product) {

            return [];

        }


        return [

            {
                key: 'movement',
                number: '01',
                label: 'MOVEMENT',
                value:
                    this.product.movement ||
                    '—'
            },

            {
                key: 'case',
                number: '02',
                label: 'CASE MATERIAL',
                value:
                    this.product.caseMaterial ||
                    '—'
            },

            {
                key: 'dial',
                number: '03',
                label: 'DIAL',
                value:
                    this.product.dialColor ||
                    '—'
            },

            {
                key: 'family',
                number: '04',
                label: 'FAMILY',
                value:
                    this.product.family ||
                    '—'
            },

            {
                key: 'model',
                number: '05',
                label: 'MODEL',
                value:
                    this.product.modelNumber ||
                    '—'
            },

            {
                key: 'code',
                number: '06',
                label: 'PRODUCT CODE',
                value:
                    this.product.productCode ||
                    '—'
            }

        ];

    }


    get cartLabel() {

        return this.isAddingToCart
            ? 'ADDING TO CART'
            : 'ADD TO CART';

    }


    // =========================================================
    // NAVIGATION
    // =========================================================

    goToWatches() {

        window.location.href =
            '/ujjayini/watches';

    }


    // =========================================================
    // ADD TO CART
    // =========================================================

    async handleAddToCart() {

        if (
            !this.product ||
            !this.product.productId
        ) {

            return;

        }


        // Guest
        if (isGuestUser) {

            this.showGuestCartModal =
                true;

            return;

        }


        // Logged-in
        this.isAddingToCart = true;


        try {

            await addToCart({

                productId:
                    this.product.productId,

                quantity: 1

            });


            this.showNotificationPopup(
                'success',
                'ADDED TO CART',
                'The timepiece has been added to your collection.'
            );

        }

        catch (error) {

            this.showNotificationPopup(
                'error',
                'UNABLE TO ADD',
                this.getErrorMessage(
                    error
                )
            );

        }

        finally {

            this.isAddingToCart = false;

        }

    }


    // =========================================================
    // PRIVATE VIEWING
    // =========================================================

    handlePrivateViewing() {

        const request =
            this.template.querySelector(
                '.request-anchor'
            );


        if (request) {

            request.scrollIntoView({
                behavior: 'smooth',
                block: 'center'
            });

        }

    }


    // =========================================================
    // GUEST MODAL
    // =========================================================

    closeGuestCartModal() {

        this.showGuestCartModal =
            false;

    }


    stopModalPropagation(event) {

        event.stopPropagation();

    }


    handleGuestLogin() {

        const startUrl =
            window.location.pathname +
            window.location.search;


        window.location.href =
            '/ujjayini/login?startURL=' +
            encodeURIComponent(
                startUrl
            );

    }


    handleGuestSignup() {

        window.location.href =
            '/ujjayini/self-register';

    }


    // =========================================================
    // NOTIFICATION
    // =========================================================

    showNotificationPopup(
        type,
        title,
        message
    ) {

        if (this.notificationTimer) {

            clearTimeout(
                this.notificationTimer
            );

        }


        this.notificationType =
            type;

        this.notificationTitle =
            title;

        this.notificationMessage =
            message;

        this.showNotification =
            true;


        this.notificationTimer =
            setTimeout(() => {

                this.showNotification =
                    false;

            }, 4000);

    }


    closeNotification() {

        this.showNotification =
            false;


        if (this.notificationTimer) {

            clearTimeout(
                this.notificationTimer
            );

            this.notificationTimer =
                null;

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


        if (error?.message) {

            return error.message;

        }


        return 'Unable to load this watch.';

    }

}