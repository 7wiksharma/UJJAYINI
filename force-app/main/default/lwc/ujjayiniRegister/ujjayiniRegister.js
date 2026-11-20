import { LightningElement } from 'lwc';

import isGuestUser from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

import register
    from '@salesforce/apex/UJJAYINIRegistrationController.register';


export default class UjjayiniRegister extends LightningElement {

    firstName = '';
    lastName = '';
    email = '';
    phone = '';
    password = '';
    confirmPassword = '';
    website = '';
    agreed = false;

    showPassword = false;
    isSubmitting = false;
    errorMessage;
    created = false;


       connectedCallback() {

        // In Experience Builder the admin is signed in, so never redirect there.
        if (!isGuestUser && !this.isBuilderPreview) {
            window.location.replace(this.sitePrefix + '/my-account');
        }
    }


    get isBuilderPreview() {

        const host = (window.location && window.location.hostname) || '';

        return /live-preview|sitepreview|\.builder\./i.test(host);
    }


    get sitePrefix() {
        return (basePath || '/ujjayini').replace(/\/s$/i, '');
    }

    get startUrl() {

        try {
            return new URLSearchParams(window.location.search).get('startURL') || '';
        } catch (error) {
            return '';
        }
    }

    get loginUrl() {

        const start = this.startUrl;

        return this.sitePrefix + '/login' +
            (start ? '?startURL=' + encodeURIComponent(start) : '');
    }

    get termsUrl() {
        return this.sitePrefix + '/terms';
    }

    get privacyUrl() {
        return this.sitePrefix + '/privacy';
    }

    get passwordType() {
        return this.showPassword ? 'text' : 'password';
    }

    get toggleLabel() {
        return this.showPassword ? 'HIDE' : 'SHOW';
    }

    get submitLabel() {
        return this.isSubmitting ? 'CREATING YOUR ACCOUNT' : 'CREATE MY ACCOUNT';
    }


    handleInput(event) {

        const field = event.target.dataset.field;

        if (field) {
            this[field] = event.target.value;
            this.errorMessage = undefined;
        }
    }

    handleAgree(event) {
        this.agreed = event.target.checked;
        this.errorMessage = undefined;
    }

    togglePassword() {
        this.showPassword = !this.showPassword;
    }

    handleKeydown(event) {

        if (event.key === 'Enter') {
            this.handleRegister();
        }
    }


    validate() {

        if (!this.firstName.trim() || !this.lastName.trim()) {
            return 'Please enter your first and last name.';
        }

        if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(this.email.trim())) {
            return 'Please enter a valid email address.';
        }

        const digits = this.phone.replace(/\D/g, '');

        if (this.phone.trim() && (digits.length < 10 || digits.length > 13)) {
            return 'Please enter a valid phone number.';
        }

        if (this.password.length < 8) {
            return 'Your password must be at least 8 characters.';
        }

        if (this.password !== this.confirmPassword) {
            return 'The passwords do not match.';
        }

        if (!this.agreed) {
            return 'Please accept the Terms and Privacy Policy.';
        }

        return null;
    }


    async handleRegister() {

        if (this.isSubmitting) {
            return;
        }

        const problem = this.validate();

        if (problem) {
            this.errorMessage = problem;
            return;
        }

        this.isSubmitting = true;
        this.errorMessage = undefined;

        try {

            const url = await register({
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.email,
                phone: this.phone,
                password: this.password,
                confirmPassword: this.confirmPassword,
                startUrl: this.startUrl,
                website: this.website
            });

            if (url) {
                window.location.href = url;
                return;
            }

            // Account created, but automatic sign in was not possible.
            this.created = true;
            this.isSubmitting = false;

        } catch (error) {

            this.errorMessage = this.getErrorMessage(error);
            this.isSubmitting = false;
        }
    }


    getErrorMessage(error) {

        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Something went wrong. Please try again.';
    }
}