import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import isGuest
    from '@salesforce/user/isGuest';

import heroVideo
    from '@salesforce/resourceUrl/UJJAYINI_Product_Detail_Video';

import getFeaturedWatches
    from '@salesforce/apex/UJJAYINIFeaturedWatchesController.getFeaturedWatches';


export default class UjjayiniHomeExperience
    extends NavigationMixin(LightningElement) {

    watches = [];

    errorMessage;

    videoUrl = heroVideo;


    @wire(getFeaturedWatches)
    wiredWatches({ data, error }) {

        if (data) {

            this.watches = data.map(
                (watch, index) => ({

                    ...watch,

                    displayIndex:
                        String(index + 1)
                            .padStart(2, '0'),

                    /*
                     * Only the useful watch information
                     * is exposed to the UI.
                     *
                     * Product ID / Product Code are NOT
                     * rendered as visible text.
                     */

                    metadata:
                        [
                            watch.movement,
                            watch.caseMaterial
                        ]
                            .filter(Boolean)
                            .join(' · ')

                })
            );

            this.errorMessage = undefined;

        }

        else if (error) {

            this.watches = [];

            this.errorMessage =
                this.getErrorMessage(error);

        }

    }


    get showEmpty() {

        return (
            !this.errorMessage &&
            this.watches.length === 0
        );

    }


    handleProductClick(event) {

        const productId =
            event.currentTarget.dataset.productId;

        if (!productId) {
            return;
        }


        this[
            NavigationMixin.Navigate
        ]({

            type: 'comm__namedPage',

            attributes: {
                name: 'Product_Detail__c'
            },

            state: {
                productId
            }

        });

    }


    handleEnterVault() {

        const vaultPath =
            '/ujjayini/collector-vault';


        const destination =
            isGuest

                ? `/ujjayini/login?startURL=${encodeURIComponent(vaultPath)}`

                : vaultPath;


        window.location.assign(
            destination
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


        if (
            error &&
            error.message
        ) {

            return error.message;

        }


        return (
            'Unable to load featured timepieces.'
        );

    }

}