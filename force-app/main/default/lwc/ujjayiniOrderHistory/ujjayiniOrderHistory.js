import { LightningElement, wire } from 'lwc';

import { NavigationMixin } from 'lightning/navigation';

import getMyOrders
    from '@salesforce/apex/UJJAYINIOrderHistoryController.getMyOrders';


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


export default class UjjayiniOrderHistory extends NavigationMixin(LightningElement) {

    orders = [];

    isLoading = true;

    errorMessage;


    @wire(getMyOrders)
    wiredOrders({ data, error }) {

        if (data) {

            this.orders = data.map(order => ({
                ...order,
                formattedTotal: this.formatPrice(order.totalAmount),
                formattedDate: this.formatDate(order.effectiveDate),
                itemLabel: order.itemCount === 1
                    ? '1 TIMEPIECE'
                    : order.itemCount + ' TIMEPIECES',
                statusClass: order.isCancelled
                    ? 'status-pill is-cancelled'
                    : 'status-pill',
                cardClass: order.isCancelled
                    ? 'order-card is-cancelled'
                    : 'order-card'
            }));

            this.errorMessage = undefined;
            this.isLoading = false;

        } else if (error) {

            this.orders = [];
            this.errorMessage = this.getErrorMessage(error);
            this.isLoading = false;
        }
    }


    get hasOrders() {
        return this.orders.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.orders.length === 0;
    }


    openOrder(event) {

        const orderId = event.currentTarget.dataset.orderId;

        if (!orderId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Order_Detail__c'
            },
            state: {
                c__orderId: orderId
            }
        });
    }

    goToWatches() {
        window.location.href = '/ujjayini/watches';
    }


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

        return 'Unable to load your orders.';
    }
}