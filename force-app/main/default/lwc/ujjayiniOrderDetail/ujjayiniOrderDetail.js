import { LightningElement, wire } from 'lwc';

import {
    CurrentPageReference,
    NavigationMixin
} from 'lightning/navigation';

import getOrderDetails
    from '@salesforce/apex/UJJAYINIOrderDetailController.getOrderDetails';

export default class UjjayiniOrderDetail extends NavigationMixin(LightningElement) {

    orderId;

    order;
    isLoading = true;
    errorMessage;

    @wire(CurrentPageReference)
    getPageReference(pageReference) {

        if (pageReference) {

            this.orderId =
                pageReference.state?.c__orderId;

        }
    }

    @wire(getOrderDetails, { orderId: '$orderId' })
    wiredOrder({ data, error }) {

        if (!this.orderId) {
            return;
        }

        this.isLoading = false;

        if (data) {

            this.order = data;
            this.errorMessage = undefined;

        } else if (error) {

            this.order = undefined;

            this.errorMessage =
                this.getErrorMessage(error);
        }
    }

    get hasOrder() {
        return !!this.order;
    }

    get hasItems() {
        return (
            this.order &&
            this.order.items &&
            this.order.items.length > 0
        );
    }

    goToCollection() {

        this[NavigationMixin.Navigate]({

            type: 'comm__namedPage',

            attributes: {
                name: 'Collector_Vault__c'
            }

        });
    }

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

        return 'Unable to load order details.';
    }
}