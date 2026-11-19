import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getMyAssets
    from '@salesforce/apex/UJJAYINICollectorVaultController.getMyAssets';

import verifyPayment
    from '@salesforce/apex/UJJAYINICollectorVaultController.verifyPayment';

import getMyWarranties
    from '@salesforce/apex/UJJAYINIWarrantyController.getMyWarranties';

import vaultBackground
    from '@salesforce/resourceUrl/UJJAYINI_Vault_Teaser_Visual';


// Check every 2 seconds, at most 15 times (about 30 seconds).
const POLL_INTERVAL_MS = 2000;
const MAX_POLL_ATTEMPTS = 15;

const BANNER_COPY = {

    VERIFYING: {
        eyebrow: 'CONFIRMING YOUR PAYMENT',
        title: 'One moment.',
        message:
            'We are verifying your payment with our records.'
    },

    PREPARING: {
        eyebrow: 'PAYMENT RECEIVED',
        title: 'Your timepiece is being prepared.',
        message:
            'It is being registered in your Collector\'s Vault.'
    },

    REGISTERED: {
        eyebrow: 'WELCOME TO YOUR COLLECTION',
        title: 'Your timepiece is now in the Vault.',
        message:
            'Its ownership record is now part of your collection.'
    },

    TIMEOUT_CONFIRMED: {
        eyebrow: 'PAYMENT CONFIRMED',
        title: 'Almost there.',
        message:
            'Your timepiece is still being registered in the Vault. ' +
            'Please refresh shortly.'
    },

    TIMEOUT_UNCONFIRMED: {
        eyebrow: 'PAYMENT UNDER CONFIRMATION',
        title: 'We have not received confirmation yet.',
        message:
            'Your timepiece will appear in the Vault as soon as your ' +
            'payment is confirmed. Please refresh shortly.'
    }
};


export default class UjjayiniCollectorVault extends LightningElement {

    assets = [];
    warranties = [];

    isLoading = true;
    errorMessage;

    wiredAssetsResult;

    // Post-payment confirmation
    paymentPhase = '';

    _paymentLinkId;
    _paymentConfirmed = false;
    _pollAttempts = 0;
    _pollTimer;
    _dismissTimer;
    _verifyInFlight = false;
    _disposed = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        this.startPaymentVerificationIfNeeded();

    }


    disconnectedCallback() {

        this._disposed = true;

        this.stopPolling();

        if (this._dismissTimer) {
            clearTimeout(this._dismissTimer);
        }

    }


    // =========================================================
    // ASSETS + WARRANTIES (unchanged behaviour)
    // =========================================================

    @wire(getMyAssets)
    wiredAssets(result) {

        this.wiredAssetsResult = result;

        const { data, error } = result;

        if (data) {

            this.assets = data.map(asset => ({
                ...asset
            }));

            this.errorMessage = undefined;

            this.loadWarranties();

        } else if (error) {

            this.isLoading = false;

            this.errorMessage =
                this.getErrorMessage(error);

        }

    }


    async loadWarranties() {

        try {

            const warrantyData =
                await getMyWarranties();

            this.warranties =
                warrantyData || [];

            this.attachWarrantiesToAssets();

        } catch (error) {

            this.errorMessage =
                this.getErrorMessage(error);

        } finally {

            this.isLoading = false;
        }

    }


    attachWarrantiesToAssets() {

        this.assets =
            this.assets.map(asset => {

                const warranty =
                    this.warranties.find(
                        item =>
                            item.assetId === asset.assetId
                    );

                return {
                    ...asset,
                    warranty: warranty || null
                };

            });

    }


    get vaultBackgroundStyle() {

        return `background-image: url("${vaultBackground}");`;

    }


    get hasAssets() {

        return this.assets.length > 0;

    }


    get hasMultipleAssets() {

        return this.assets.length > 1;

    }


    get isEmpty() {

        return (
            !this.isLoading &&
            !this.errorMessage &&
            !this.isVerifyingPayment &&
            this.assets.length === 0
        );

    }


    // =========================================================
    // POST-PAYMENT VERIFICATION
    //
    // The URL parameter is only a trigger. Salesforce decides
    // whether the payment is captured and the Asset exists.
    // =========================================================

    startPaymentVerificationIfNeeded() {

        let params;

        try {

            params = new URLSearchParams(window.location.search);

        } catch (error) {

            return;

        }

        const status =
            params.get('razorpay_payment_link_status');

        if (!status || status.toLowerCase() !== 'paid') {
            return;
        }

        this._paymentLinkId =
            params.get('razorpay_payment_link_id');

        this._paymentConfirmed = false;

        this._pollAttempts = 0;

        this.paymentPhase = 'VERIFYING';

        this.verifyPaymentOnce();

    }


    async verifyPaymentOnce() {

        if (this._disposed || this._verifyInFlight) {
            return;
        }

        this._verifyInFlight = true;

        this._pollAttempts += 1;

        let verification = null;

        try {

            verification = await verifyPayment({
                paymentLinkId: this._paymentLinkId
            });

        } catch (error) {

            // A network hiccup must not stop the polling.
            verification = null;

        } finally {

            this._verifyInFlight = false;

        }

        if (this._disposed) {
            return;
        }

        if (verification && verification.assetReady) {

            await this.finishPaymentVerification();

            return;
        }

        if (verification && verification.paymentConfirmed) {
            this._paymentConfirmed = true;
        }

        if (this._pollAttempts >= MAX_POLL_ATTEMPTS) {

            this.paymentPhase =
                this._paymentConfirmed
                    ? 'TIMEOUT_CONFIRMED'
                    : 'TIMEOUT_UNCONFIRMED';

            return;
        }

        this.paymentPhase =
            this._paymentConfirmed
                ? 'PREPARING'
                : 'VERIFYING';

        this._pollTimer = setTimeout(
            () => this.verifyPaymentOnce(),
            POLL_INTERVAL_MS
        );

    }


    async finishPaymentVerification() {

        this.stopPolling();

        try {

            if (this.wiredAssetsResult) {
                await refreshApex(this.wiredAssetsResult);
            }

        } catch (error) {

            // The wire will deliver the data on its next refresh.

        }

        if (this._disposed) {
            return;
        }

        this.paymentPhase = 'REGISTERED';

        this.removePaymentParamsFromUrl();

        this._dismissTimer = setTimeout(() => {

            if (this.paymentPhase === 'REGISTERED') {
                this.paymentPhase = '';
            }

        }, 12000);

    }


    stopPolling() {

        if (this._pollTimer) {

            clearTimeout(this._pollTimer);

            this._pollTimer = null;
        }

    }


    removePaymentParamsFromUrl() {

        try {

            const url = new URL(window.location.href);

            const razorpayKeys =
                Array.from(url.searchParams.keys())
                    .filter(key => key.startsWith('razorpay_'));

            if (razorpayKeys.length === 0) {
                return;
            }

            razorpayKeys.forEach(key => {
                url.searchParams.delete(key);
            });

            window.history.replaceState(
                window.history.state,
                '',
                url.pathname + url.search + url.hash
            );

        } catch (error) {

            // Cleaning the address bar is cosmetic only.

        }

    }


    handleDismissPayment() {

        this.paymentPhase = '';

    }


    handleRefreshVault() {

        window.location.reload();

    }


    // =========================================================
    // PAYMENT BANNER
    // =========================================================

    get showPaymentBanner() {

        return !!this.paymentPhase;

    }


    get isVerifyingPayment() {

        return (
            this.paymentPhase === 'VERIFYING' ||
            this.paymentPhase === 'PREPARING'
        );

    }


    get showRefresh() {

        return (
            this.paymentPhase === 'TIMEOUT_CONFIRMED' ||
            this.paymentPhase === 'TIMEOUT_UNCONFIRMED'
        );

    }


    get paymentBannerClass() {

        return this.isVerifyingPayment
            ? 'payment-banner is-working'
            : 'payment-banner is-done';

    }


    get paymentBannerEyebrow() {

        return (BANNER_COPY[this.paymentPhase] || {}).eyebrow;

    }


    get paymentBannerTitle() {

        return (BANNER_COPY[this.paymentPhase] || {}).title;

    }


    get paymentBannerMessage() {

        return (BANNER_COPY[this.paymentPhase] || {}).message;

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


        return 'Unable to load your collection.';

    }

}