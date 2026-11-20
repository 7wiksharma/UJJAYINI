import { LightningElement, api } from 'lwc';

import getCheckoutAddress
    from '@salesforce/apex/UJJAYINICheckoutAddressController.getCheckoutAddress';

import saveShippingAddress
    from '@salesforce/apex/UJJAYINICheckoutAddressController.saveShippingAddress';


export default class UjjayiniCheckoutAddress extends LightningElement {

    fullName = '';
    email = '';

    phone = '';
    line1 = '';
    line2 = '';
    city = '';
    state = '';
    postalCode = '';
    country = 'India';

    isLoading = true;
    isSaving = false;
    isSaved = false;

    errorMessage;


    connectedCallback() {

        this.loadAddress();

    }


    async loadAddress() {

        try {

            const address =
                await getCheckoutAddress();

            if (address) {

                this.fullName = address.fullName || '';
                this.email = address.email || '';
                this.phone = address.phone || '';
                this.line1 = address.line1 || '';
                this.line2 = address.line2 || '';
                this.city = address.city || '';
                this.state = address.state || '';
                this.postalCode = address.postalCode || '';
                this.country = address.country || 'India';

                this.isSaved = !!address.isSavedOnOrder;
            }

        } catch (error) {

            this.errorMessage =
                this.getErrorMessage(error);

        } finally {

            this.isLoading = false;

        }

    }


    handleInput(event) {

        const field =
            event.target.dataset.field;

        if (!field) {
            return;
        }

        this[field] = event.target.value;

        this.isSaved = false;

        this.errorMessage = undefined;

    }


    validate() {

        const phoneDigits =
            (this.phone || '').replace(/\D/g, '');

        if (phoneDigits.length < 10 || phoneDigits.length > 13) {
            return 'Please enter a valid phone number.';
        }

        if (!this.line1.trim()) {
            return 'Please enter your address.';
        }

        if (!this.city.trim()) {
            return 'Please enter your city.';
        }

        if (!this.state.trim()) {
            return 'Please enter your state.';
        }

        const isIndia =
            !this.country ||
            this.country.trim().toLowerCase() === 'india';

        if (isIndia && !/^\d{6}$/.test(this.postalCode.trim())) {
            return 'Please enter a valid 6-digit PIN code.';
        }

        if (!this.postalCode.trim()) {
            return 'Please enter your postal code.';
        }

        return null;

    }


    /*
     * Called by the cart before payment.
     * Resolves true only when the address is saved on the server.
     */
    @api
    async save() {

        const problem =
            this.validate();

        if (problem) {

            this.errorMessage = problem;

            this.scrollToForm();

            return false;
        }

        this.isSaving = true;

        try {

            await saveShippingAddress({
                phone: this.phone,
                line1: this.line1,
                line2: this.line2,
                city: this.city,
                state: this.state,
                postalCode: this.postalCode,
                country: this.country
            });

            this.isSaved = true;

            this.errorMessage = undefined;

            return true;

        } catch (error) {

            this.errorMessage =
                this.getErrorMessage(error);

            this.scrollToForm();

            return false;

        } finally {

            this.isSaving = false;

        }

    }


    scrollToForm() {

        const form =
            this.template.querySelector('.address-block');

        if (form) {

            form.scrollIntoView({
                behavior: 'smooth',
                block: 'center'
            });
        }

    }


    get showDeliveringTo() {

        return !!(this.fullName || this.email);

    }


    getErrorMessage(error) {

        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Unable to save your address.';

    }

}