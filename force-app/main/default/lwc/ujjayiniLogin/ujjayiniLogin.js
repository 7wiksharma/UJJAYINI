import { LightningElement } from 'lwc';

import isGuestUser from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

import login
    from '@salesforce/apex/UJJAYINILoginController.login';

import forgotPassword
    from '@salesforce/apex/UJJAYINILoginController.forgotPassword';


export default class UjjayiniLogin extends LightningElement {

    identifier = '';
    password = '';

    showPassword = false;
    isSubmitting = false;
    errorMessage;

    mode = 'login';
    resetSent = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================
    connectedCallback() {

        // In Experience Builder the admin is signed in, so never redirect there.
        if (!isGuestUser && !this.isBuilderPreview) {
            window.location.replace(this.redirectTarget);
        }
    }


    get isBuilderPreview() {

        const host = (window.location && window.location.hostname) || '';

        return /live-preview|sitepreview|\.builder\./i.test(host);
    }


    // =========================================================
    // URLS
    // =========================================================

    get sitePrefix() {
        return (basePath || '/ujjayini').replace(/\/s$/i, '');
    }

    get startUrl() {

        try {

            const params = new URLSearchParams(window.location.search);

            return params.get('startURL') || params.get('startUrl') || '';

        } catch (error) {

            return '';
        }
    }

    get redirectTarget() {

        const start = this.startUrl;

        return start && start.startsWith('/') && !start.startsWith('//')
            ? start
            : this.sitePrefix + '/my-account';
    }

    get signupUrl() {

        const start = this.startUrl;

        return this.sitePrefix + '/SelfRegister' +
            (start ? '?startURL=' + encodeURIComponent(start) : '');
    }

    get homeUrl() {
        return this.sitePrefix + '/';
    }


    // =========================================================
    // VIEW STATE
    // =========================================================

    get isLoginMode() {
        return this.mode === 'login';
    }

    get passwordType() {
        return this.showPassword ? 'text' : 'password';
    }

    get toggleLabel() {
        return this.showPassword ? 'HIDE' : 'SHOW';
    }

    get signInLabel() {
        return this.isSubmitting ? 'SIGNING IN' : 'SIGN IN';
    }

    get resetLabel() {
        return this.isSubmitting ? 'SENDING' : 'SEND RESET LINK';
    }


    // =========================================================
    // FORM
    // =========================================================

    handleInput(event) {

        const field = event.target.dataset.field;

        if (field) {
            this[field] = event.target.value;
            this.errorMessage = undefined;
        }
    }

    togglePassword() {
        this.showPassword = !this.showPassword;
    }

    handleKeydown(event) {

        if (event.key !== 'Enter') {
            return;
        }

        if (this.isLoginMode) {
            this.handleLogin();
        } else {
            this.handleReset();
        }
    }

    async handleLogin() {

        if (this.isSubmitting) {
            return;
        }

        if (!this.identifier.trim() || !this.password) {
            this.errorMessage = 'Please enter your email and password.';
            return;
        }

        this.isSubmitting = true;
        this.errorMessage = undefined;

        try {

            const url = await login({
                identifier: this.identifier,
                password: this.password,
                startUrl: this.startUrl
            });

            // Stay in the "signing in" state while the browser moves on.
            window.location.href = url;

        } catch (error) {

            this.errorMessage = this.getErrorMessage(error);
            this.isSubmitting = false;
        }
    }

    showReset() {
        this.mode = 'reset';
        this.resetSent = false;
        this.errorMessage = undefined;
    }

    showLogin() {
        this.mode = 'login';
        this.errorMessage = undefined;
    }

    async handleReset() {

        if (this.isSubmitting) {
            return;
        }

        if (!this.identifier.trim()) {
            this.errorMessage = 'Please enter your email.';
            return;
        }

        this.isSubmitting = true;
        this.errorMessage = undefined;

        try {

            await forgotPassword({ identifier: this.identifier });

            this.resetSent = true;

        } catch (error) {

            this.errorMessage = this.getErrorMessage(error);

        } finally {

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