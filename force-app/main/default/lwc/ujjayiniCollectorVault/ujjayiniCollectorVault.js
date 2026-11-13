import { LightningElement, wire } from 'lwc';

import getMyAssets
    from '@salesforce/apex/UJJAYINICollectorVaultController.getMyAssets';

import getMyWarranties
    from '@salesforce/apex/UJJAYINIWarrantyController.getMyWarranties';

export default class UjjayiniCollectorVault extends LightningElement {

    assets = [];
    warranties = [];

    isLoading = true;
    errorMessage;

    @wire(getMyAssets)
    wiredAssets({ data, error }) {

        if (data) {

            this.assets = data.map(asset => ({
                ...asset
            }));

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

    get hasAssets() {
        return this.assets.length > 0;
    }

    get isEmpty() {
        return (
            !this.isLoading &&
            !this.errorMessage &&
            this.assets.length === 0
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

        return 'Unable to load your collection.';
    }
}