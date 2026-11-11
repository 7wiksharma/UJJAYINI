import { LightningElement, wire } from 'lwc';
import getProducts from '@salesforce/apex/UJJAYINIProductCatalogController.getProducts';

export default class UjjayiniProductCatalog extends LightningElement {

    products = [];
    error;
    isLoading = true;

    @wire(getProducts)
    wiredProducts({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.products = data;
            this.error = undefined;
        } else if (error) {
            this.products = [];
            this.error = error;
        }
    }

    get hasProducts() {
        return this.products.length > 0;
    }

    get hasError() {
        return this.error != null;
    }
}