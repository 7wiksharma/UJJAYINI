import { LightningElement, api } from 'lwc';

import createRequest
    from '@salesforce/apex/UJJAYINIWatchRequestController.createRequest';

export default class UjjayiniWatchRequest extends LightningElement {

    @api watchId;

    requestType = 'Notify Me';
    requestedQuantity = 1;
    customerNote = '';

    isSubmitting = false;

    successMessage;
    errorMessage;

    get requestTypeOptions() {

        return [
            {
                label: 'Notify Me',
                value: 'Notify Me'
            },
            {
                label: 'Pre-Order',
                value: 'Pre-Order'
            },
            {
                label: 'Custom Request',
                value: 'Custom Request'
            }
        ];
    }


    handleRequestTypeChange(event) {

        this.requestType =
            event.detail.value;

        this.successMessage = undefined;
        this.errorMessage = undefined;
    }


    handleQuantityChange(event) {

        this.requestedQuantity =
            Number(event.target.value);

        this.successMessage = undefined;
        this.errorMessage = undefined;
    }


    handleNoteChange(event) {

        this.customerNote =
            event.target.value;

        this.successMessage = undefined;
        this.errorMessage = undefined;
    }


    async handleSubmit() {

        this.successMessage = undefined;
        this.errorMessage = undefined;


        if (!this.watchId) {

            this.errorMessage =
                'Watch information is missing.';

            return;
        }


        if (
            !this.requestedQuantity ||
            this.requestedQuantity <= 0
        ) {

            this.errorMessage =
                'Requested quantity must be greater than zero.';

            return;
        }


        this.isSubmitting = true;


        try {

            const result =
                await createRequest({
                    watchId: this.watchId,
                    requestType: this.requestType,
                    requestedQuantity:
                        this.requestedQuantity,
                    customerNote:
                        this.customerNote
                });


            this.successMessage =
                result.message;


            this.customerNote = '';
            this.requestedQuantity = 1;
            this.requestType = 'Notify Me';

        } catch (error) {

            this.errorMessage =
                this.getErrorMessage(error);

        } finally {

            this.isSubmitting = false;
        }
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

        return 'Something went wrong.';
    }
}