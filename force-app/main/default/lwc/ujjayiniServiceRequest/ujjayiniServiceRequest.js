import { LightningElement } from 'lwc';

import createRequest
    from '@salesforce/apex/UJJAYINIServiceRequestController.createRequest';

export default class UjjayiniServiceRequest extends LightningElement {

    serviceType = 'Repair';
    priority = 'Medium';
    description = '';

    isSubmitting = false;

    successMessage;
    errorMessage;

    get serviceTypeOptions() {
        return [
            { label: 'Repair', value: 'Repair' },
            { label: 'Maintenance', value: 'Maintenance' },
            { label: 'Inspection', value: 'Inspection' },
            { label: 'Warranty Claim', value: 'Warranty Claim' },
            { label: 'Replacement', value: 'Replacement' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get priorityOptions() {
        return [
            { label: 'Low', value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High', value: 'High' },
            { label: 'Urgent', value: 'Urgent' }
        ];
    }

    handleServiceTypeChange(event) {
        this.serviceType = event.detail.value;
        this.clearMessages();
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
        this.clearMessages();
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
        this.clearMessages();
    }

    async handleSubmit() {

        this.clearMessages();

        if (!this.description || !this.description.trim()) {

            this.errorMessage =
                'Please describe the service you need.';

            return;
        }

        this.isSubmitting = true;

        try {

            const result =
                await createRequest({
                    serviceType: this.serviceType,
                    priority: this.priority,
                    description: this.description
                });

            this.successMessage =
                result.message;

            this.description = '';
            this.serviceType = 'Repair';
            this.priority = 'Medium';

        } catch (error) {

            this.errorMessage =
                this.getErrorMessage(error);

        } finally {

            this.isSubmitting = false;
        }
    }

    clearMessages() {
        this.successMessage = undefined;
        this.errorMessage = undefined;
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

        return 'Unable to submit your service request.';
    }
}