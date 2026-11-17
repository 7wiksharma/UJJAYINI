import { LightningElement, wire } from 'lwc';

import getCollectionsWithWatches
    from '@salesforce/apex/UJJAYINICollectionController.getCollectionsWithWatches';

import HERO_IMAGE
    from '@salesforce/resourceUrl/UJJAYINI_Collections_Hero';

export default class UjjayiniCollectionSection extends LightningElement {

    collections = [];
    errorMessage;


    // =========================================================
    // HERO STATIC RESOURCE
    // =========================================================

    get heroPhotoStyle() {

        return `
            background-image: url("${HERO_IMAGE}");
        `;
    }


    // =========================================================
    // LOAD COLLECTIONS
    // =========================================================

    @wire(getCollectionsWithWatches)
    wiredCollections({ data, error }) {

        if (data) {

            this.collections = data.map(
                (collection, index) => {

                    const displayIndex =
                        String(index + 1).padStart(2, '0');

                    return {
                        ...collection,

                        displayIndex,

                        /*
                         * Apex returns:
                         * description
                         *
                         * HTML expects:
                         * shortDescription
                         */
                        shortDescription:
                            collection.description,

                        categoryLabel:
                            this.getCategoryLabel(
                                collection.name
                            ),

                        signature:
                            this.getSignature(
                                collection.name
                            )
                    };
                }
            );

            this.errorMessage = undefined;

        } else if (error) {

            this.collections = [];

            this.errorMessage =
                this.getErrorMessage(error);
        }
    }


    // =========================================================
    // EMPTY STATE
    // =========================================================

    get showEmpty() {

        return (
            !this.errorMessage &&
            this.collections.length === 0
        );
    }


    // =========================================================
    // COLLECTION CARD CLICK
    // =========================================================
    //
    // ALL collection cards intentionally go to:
    //
    // /ujjayini/watches
    //
    // We DO NOT use:
    //
    // /ujjayini/watches?collection=Ayas
    // /ujjayini/watches?collection=Indranila
    // /ujjayini/watches?collection=Hiranya
    //
    // The Watches page will contain every collection
    // section-wise.
    //
    // =========================================================

    handleCollectionClick() {

        window.location.href =
            '/ujjayini/watches';
    }


    // =========================================================
    // CATEGORY LABEL
    // =========================================================

    getCategoryLabel(name) {

        if (!name) {
            return 'HOROLOGY';
        }

        const normalized =
            name.toLowerCase();

        if (
            normalized.includes('indran')
        ) {
            return 'CELESTIAL';
        }

        if (
            normalized.includes('hiranya')
        ) {
            return 'RADIANCE';
        }

        if (
            normalized.includes('ayas')
        ) {
            return 'PERMANENCE';
        }

        return 'THE COLLECTION';
    }


    // =========================================================
    // SIGNATURE
    // =========================================================

    getSignature(name) {

        if (!name) {
            return 'TIME · UJJAYINI';
        }

        const normalized =
            name.toLowerCase();

        if (
            normalized.includes('indran')
        ) {
            return 'SAPPHIRE · MIDNIGHT';
        }

        if (
            normalized.includes('hiranya')
        ) {
            return 'GOLD · DAWN';
        }

        if (
            normalized.includes('ayas')
        ) {
            return 'STEEL · ETERNAL';
        }

        return 'UJJAYINI · HOROLOGY';
    }


    // =========================================================
    // ERROR MESSAGE
    // =========================================================

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
            'Unable to load the UJJAYINI collections.'
        );
    }
}