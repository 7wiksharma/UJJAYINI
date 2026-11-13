import { LightningElement, wire } from 'lwc';

import getMyServiceRequests
    from '@salesforce/apex/UJJAYINIServiceRequestController.getMyServiceRequests';

export default class UjjayiniServiceRequests extends LightningElement {

    requests = [];
    isLoading = true;
    errorMessage;

    @wire(getMyServiceRequests)
    wiredRequests({ data, error }) {

        this.isLoading = false;

        if (data) {

            this.requests =
                (data || []).map(request => ({
                    ...request
                }));

            this.errorMessage = undefined;

        } else if (error) {

            this.requests = [];

            this.errorMessage =
                this.getErrorMessage(error);
        }
    }

    get hasRequests() {
        return this.requests.length > 0;
    }

    get isEmpty() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.requests.length === 0
        );
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

        return 'Unable to load your service requests.';
    }
}