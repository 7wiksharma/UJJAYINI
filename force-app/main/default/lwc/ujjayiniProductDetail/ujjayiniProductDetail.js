import { LightningElement, wire } from 'lwc';

import getProduct
    from '@salesforce/apex/UJJAYINIProductCatalogController.getProduct';

import { CurrentPageReference } from 'lightning/navigation';

export default class UjjayiniProductDetail extends LightningElement {

    productId;

    product;
    isLoading = true;
    errorMessage;

    @wire(CurrentPageReference)
    getPageReference(pageReference) {

        if (
            pageReference &&
            pageReference.state
        ) {

            const productId =
                pageReference.state.productId ||
                pageReference.state.c__productId;

            if (
                productId &&
                productId !== this.productId
            ) {

                this.productId = productId;

                this.loadProduct();
            }
        }
    }

    async loadProduct() {

        if (!this.productId) {
            this.isLoading = false;
            this.errorMessage =
                'Product information is missing.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;

        try {

            this.product =
                await getProduct({
                    productId: this.productId
                });

        } catch (error) {

            this.product = undefined;

            this.errorMessage =
                this.getErrorMessage(error);

        } finally {

            this.isLoading = false;

        }
    }

    get hasProduct() {
        return !!this.product;
    }

    get formattedPrice() {

        if (
            this.product &&
            this.product.price !== null &&
            this.product.price !== undefined
        ) {

            return new Intl.NumberFormat(
                'en-IN',
                {
                    style: 'currency',
                    currency: 'INR',
                    maximumFractionDigits: 0
                }
            ).format(this.product.price);

        }

        return 'Price unavailable';
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

        return 'Unable to load this watch.';
    }
}