import { LightningElement } from 'lwc';

import isGuest from '@salesforce/user/isGuest';

import getMyServiceRequests
    from '@salesforce/apex/UJJAYINIServiceRequestController.getMyServiceRequests';

export default class UjjayiniServiceRequests extends LightningElement {

    requests = [];

    isLoading = false;

    errorMessage;

    isGuestUser = isGuest;


    connectedCallback() {

        if (this.isGuestUser) {

            this.isLoading = false;

            return;
        }

        this.loadRequests();
    }


    async loadRequests() {

        this.isLoading = true;

        this.errorMessage = undefined;

        try {

            const data =
                await getMyServiceRequests();

            this.requests =
                (data || []).map(request => ({
                    ...request,

                    formattedDate:
                        this.formatDate(
                            request.requestDate
                        )
                }));

        } catch (error) {

            this.requests = [];

            this.errorMessage =
                this.getErrorMessage(error);

        } finally {

            this.isLoading = false;
        }
    }


    get hasRequests() {

        return this.requests.length > 0;
    }


    get isEmpty() {

        return (
            !this.isLoading &&
            !this.errorMessage &&
            !this.isGuestUser &&
            this.requests.length === 0
        );
    }


    get showGuestState() {

        return this.isGuestUser;
    }


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

        return 'Unable to load your service requests.';
    }


    formatDate(value) {

        if (!value) {
            return '—';
        }

        try {

            return new Intl.DateTimeFormat(
                'en-IN',
                {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric'
                }
            ).format(
                new Date(value)
            );

        } catch (error) {

            return value;
        }
    }
}