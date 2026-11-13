import { LightningElement, wire } from 'lwc';

import { NavigationMixin } from 'lightning/navigation';

import getMyOrders
    from '@salesforce/apex/UJJAYINIOrderHistoryController.getMyOrders';

export default class UjjayiniOrderHistory extends NavigationMixin(LightningElement) {

    orders = [];
    isLoading = true;
    errorMessage;

    @wire(getMyOrders)
    wiredOrders({ data, error }) {

        this.isLoading = false;

        if (data) {

            this.orders =
                (data || []).map(order => ({
                    ...order
                }));

            this.errorMessage = undefined;

        } else if (error) {

            this.orders = [];

            this.errorMessage =
                this.getErrorMessage(error);
        }
    }

    get hasOrders() {
        return this.orders.length > 0;
    }

    get isEmpty() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.orders.length === 0
        );
    }

    openOrder(event) {

        const orderId =
            event.currentTarget.dataset.orderId;

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

        return 'Unable to load your orders.';
    }
}