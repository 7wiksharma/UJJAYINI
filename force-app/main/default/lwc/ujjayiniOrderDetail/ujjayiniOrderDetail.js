import { LightningElement, wire } from 'lwc';

import {
    CurrentPageReference,
    NavigationMixin
} from 'lightning/navigation';

import { refreshApex } from '@salesforce/apex';

import getOrderDetails
    from '@salesforce/apex/UJJAYINIOrderDetailController.getOrderDetails';

import cancelOrder
    from '@salesforce/apex/UJJAYINIOrderDetailController.cancelOrder';
import getMyInvoice
    from '@salesforce/apex/UJJAYINIInvoiceController.getMyInvoice';

const PRICE = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
});

const DATE = new Intl.DateTimeFormat('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
});

const TRACKING_STEPS = [
    'Processing',
    'Packed',
    'Shipped',
    'Out for Delivery',
    'Delivered'
];


export default class UjjayiniOrderDetail extends NavigationMixin(LightningElement) {

    orderId;

    order;

    isLoading = true;

    errorMessage;

    wiredOrderResult;

    showCancelModal = false;

    isCancelling = false;

    cancelError;

    notice;
    
    isDownloadingInvoice = false;

    invoiceError;

    @wire(CurrentPageReference)
    getPageReference(pageReference) {

        if (!pageReference) {
            return;
        }

        const state = pageReference.state || {};

        const requested =
            state.c__orderId ||
            state.orderId;

        if (requested) {

            this.orderId = requested;

        } else {

            this.isLoading = false;

            this.errorMessage =
                'Order information is missing.';
        }
    }


    @wire(getOrderDetails, { orderId: '$orderId' })
    wiredOrder(result) {

        this.wiredOrderResult = result;

        const { data, error } = result;

        if (!this.orderId) {
            return;
        }

        if (data) {

            this.order = data;
            this.errorMessage = undefined;
            this.isLoading = false;

        } else if (error) {

            this.order = undefined;
            this.errorMessage = this.getErrorMessage(error);
            this.isLoading = false;
        }
    }


    // =========================================================
    // HEADER
    // =========================================================

    get hasOrder() {
        return !!this.order;
    }

    get headline() {

        const items = (this.order && this.order.items) || [];

        if (items.length === 0) {
            return 'Your UJJAYINI order';
        }

        const first = items[0].productName;

        return items.length === 1
            ? first
            : first + ' & ' + (items.length - 1) + ' more';
    }

    get formattedDate() {
        return this.formatDate(this.order && this.order.effectiveDate);
    }

    get formattedTotal() {
        return this.formatPrice(this.order && this.order.totalAmount);
    }

    get statusClass() {

        if (!this.order) {
            return 'status-pill';
        }

        return this.order.isCancelled
            ? 'status-pill is-cancelled'
            : 'status-pill is-confirmed';
    }


    // =========================================================
    // TRACKING
    // =========================================================

    get showTracking() {

        return !!(
            this.order &&
            !this.order.isCancelled &&
            this.order.status !== 'Draft'
        );
    }

    get trackingSteps() {

        const current =
            TRACKING_STEPS.indexOf(
                (this.order && this.order.fulfillmentStatus) || 'Processing'
            );

        return TRACKING_STEPS.map((label, index) => {

            let className = 'track-step';

            if (index < current) {
                className += ' is-done';
            } else if (index === current) {
                className += ' is-current';
            }

            return {
                key: label,
                label: label.toUpperCase(),
                className
            };
        });
    }


    // =========================================================
    // ITEMS, DELIVERY, PAYMENT
    // =========================================================

    get items() {

        if (!this.order || !this.order.items) {
            return [];
        }

        return this.order.items.map(item => ({
            ...item,
            formattedUnit: this.formatPrice(item.unitPrice),
            formattedTotal: this.formatPrice(item.totalPrice),
            quantityNumber: Number(item.quantity)
        }));
    }

    get hasShipping() {
        return !!(this.order && this.order.shippingPostalCode);
    }

    get shippingLines() {

        if (!this.hasShipping) {
            return [];
        }

        const order = this.order;

        const lines = (order.shippingStreet || '')
            .split('\n')
            .map(line => line.trim())
            .filter(line => line);

        const cityLine = [
            order.shippingCity,
            order.shippingState,
            order.shippingPostalCode
        ].filter(part => part).join(', ');

        if (cityLine) {
            lines.push(cityLine);
        }

        if (order.shippingCountry) {
            lines.push(order.shippingCountry);
        }

        return lines.map((text, index) => ({ key: 'line-' + index, text }));
    }

    get hasPayment() {
        return !!(this.order && this.order.paymentStatus);
    }

    get paidAtLabel() {
        return this.formatDate(this.order && this.order.paidAt);
    }

    get refundedAtLabel() {
        return this.formatDate(this.order && this.order.refundedAt);
    }

    get isRefunded() {
        return !!(this.order && this.order.paymentStatus === 'Refunded');
    }

    get cancelledAtLabel() {
        return this.formatDate(this.order && this.order.cancelledAt);
    }

    get canCancel() {
        return !!(this.order && this.order.canCancel);
    }


    // =========================================================
    // CANCELLATION
    // =========================================================

    openCancelModal() {
        this.cancelError = undefined;
        this.showCancelModal = true;
    }

    closeCancelModal() {

        if (this.isCancelling) {
            return;
        }

        this.showCancelModal = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    async confirmCancel() {

        if (this.isCancelling) {
            return;
        }

        this.isCancelling = true;
        this.cancelError = undefined;

        try {

            const result = await cancelOrder({ orderId: this.orderId });

            this.notice = result && result.message;

            this.showCancelModal = false;

            await refreshApex(this.wiredOrderResult);

        } catch (error) {

            this.cancelError = this.getErrorMessage(error);

        } finally {

            this.isCancelling = false;
        }
    }

    // =========================================================
    // INVOICE
    // =========================================================

    get canDownloadInvoice() {
        return !!(this.order && this.order.status !== 'Draft');
    }

    get invoiceLabel() {
        return this.isDownloadingInvoice
            ? 'PREPARING INVOICE'
            : 'DOWNLOAD INVOICE';
    }

    async handleDownloadInvoice() {

        if (this.isDownloadingInvoice) {
            return;
        }

        this.isDownloadingInvoice = true;
        this.invoiceError = undefined;

        try {

            const file = await getMyInvoice({ orderId: this.orderId });

            const link = document.createElement('a');

            link.href = 'data:application/pdf;base64,' + file.base64Pdf;
            link.download = file.fileName;

            link.click();

        } catch (error) {

            this.invoiceError = this.getErrorMessage(error);

        } finally {

            this.isDownloadingInvoice = false;
        }
    }
    // =========================================================
    // NAVIGATION
    // =========================================================

    goBack() {
        window.location.href = '/ujjayini/order-history';
    }

    goToCollection() {

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Collector_Vault__c'
            }
        });
    }

    goToService() {
        window.location.href = '/ujjayini/service';
    }


    // =========================================================
    // HELPERS
    // =========================================================

    formatPrice(value) {

        if (value === null || value === undefined) {
            return '';
        }

        return PRICE.format(Number(value));
    }

    formatDate(value) {

        if (!value) {
            return '';
        }

        const parsed = new Date(value);

        return isNaN(parsed.getTime())
            ? String(value)
            : DATE.format(parsed);
    }

    getErrorMessage(error) {

        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Unable to load order details.';
    }
}