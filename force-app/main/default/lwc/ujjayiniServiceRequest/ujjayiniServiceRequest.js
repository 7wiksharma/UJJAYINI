import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import createRequest
    from '@salesforce/apex/UJJAYINIServiceRequestController.createRequest';

import getMyAssets
    from '@salesforce/apex/UJJAYINICollectorVaultController.getMyAssets';


const SERVICE_TYPES = [
    'Repair',
    'Maintenance',
    'Inspection',
    'Warranty Claim',
    'Replacement',
    'Other'
];

const PRIORITIES = [
    'Low',
    'Medium',
    'High',
    'Urgent'
];


export default class UjjayiniServiceRequest extends LightningElement {

    serviceType = 'Repair';
    priority = 'Medium';
    description = '';

    // The selected timepiece ('' means no specific timepiece).
    assetId = '';

    assets = [];
    requestedAssetId;

    isSubmitting = false;

    successMessage;
    errorMessage;


    // =========================================================
    // WATCH PASSED FROM THE COLLECTOR VAULT (?assetId=...)
    //
    // It is only preselected when it is one of the customer's
    // own timepieces. The server validates ownership again.
    // =========================================================

    @wire(CurrentPageReference)
    getPageReference(pageReference) {

        let requested;

        if (pageReference && pageReference.state) {

            requested =
                pageReference.state.assetId ||
                pageReference.state.c__assetId;
        }

        if (!requested) {

            try {

                requested =
                    new URLSearchParams(
                        window.location.search
                    ).get('assetId');

            } catch (error) {

                requested = undefined;
            }
        }

        if (requested) {

            this.requestedAssetId = requested;

            this.applyRequestedAsset();
        }
    }


    @wire(getMyAssets)
    wiredAssets({ data, error }) {

        if (data) {

            this.assets = data;

            this.applyRequestedAsset();

        } else if (error) {

            // The timepiece selector is optional.
            this.assets = [];
        }
    }


    applyRequestedAsset() {

        if (!this.requestedAssetId || this.assetId) {
            return;
        }

        const owned =
            this.assets.find(
                asset =>
                    asset.assetId === this.requestedAssetId
            );

        if (owned) {
            this.assetId = owned.assetId;
        }
    }


    // =========================================================
    // OPTIONS
    // =========================================================

    get showAssetSelector() {
        return this.assets.length > 0;
    }

    get assetOptions() {

        const options = [
            {
                key: 'none',
                label: 'No specific timepiece',
                value: '',
                selected: !this.assetId
            }
        ];

        this.assets.forEach(asset => {

            const purchased =
                asset.purchaseDate
                    ? ' · purchased ' + asset.purchaseDate
                    : '';

            options.push({
                key: asset.assetId,
                label: asset.productName + purchased,
                value: asset.assetId,
                selected: asset.assetId === this.assetId
            });
        });

        return options;
    }

    get serviceTypeOptions() {

        return SERVICE_TYPES.map(value => ({
            key: value,
            label: value,
            value,
            selected: value === this.serviceType
        }));
    }

    get priorityOptions() {

        return PRIORITIES.map(value => ({
            key: value,
            label: value,
            value,
            selected: value === this.priority
        }));
    }


    // =========================================================
    // HANDLERS
    // =========================================================

    handleAssetChange(event) {
        this.assetId = event.target.value;
        this.clearMessages();
    }

    handleServiceTypeChange(event) {
        this.serviceType = event.target.value;
        this.clearMessages();
    }

    handlePriorityChange(event) {
        this.priority = event.target.value;
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
                    description: this.description,
                    assetId: this.assetId || null
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