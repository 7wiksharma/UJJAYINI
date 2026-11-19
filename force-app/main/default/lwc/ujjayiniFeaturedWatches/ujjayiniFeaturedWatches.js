import { LightningElement, wire } from 'lwc';

import getFeaturedWatches
    from '@salesforce/apex/UJJAYINIFeaturedWatchesController.getFeaturedWatches';


export default class UjjayiniFeaturedWatches extends LightningElement {

    watches = [];

    errorMessage;


    @wire(getFeaturedWatches)
    wiredWatches({ data, error }) {

        if (data) {

            this.watches =
                data.map((watch, index) => ({
                    ...watch,

                    displayIndex:
                        String(index + 1).padStart(2, '0'),

                    metadata:
                        [watch.movement, watch.caseMaterial]
                            .filter(Boolean)
                            .join(' · ')
                }));

            this.errorMessage = undefined;

        } else if (error) {

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


    handleExplore(event) {

        const productId =
            event.currentTarget.dataset.id;

        if (!productId) {
            return;
        }

        /*
         * Product Detail routing will be connected
         * when we build the Product Detail page.
         *
         * For now we keep the product ID available
         * without hard-coding the future route.
         */

        window.dispatchEvent(
            new CustomEvent(
                'ujjayini-product-selected',
                {
                    detail: {
                        productId
                    }
                }
            )
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

        if (error && error.message) {

            return error.message;

        }

        return 'Unable to load featured timepieces.';

    }

}
