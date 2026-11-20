import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import isGuestUser from '@salesforce/user/isGuest';

import submitEnquiry
    from '@salesforce/apex/UJJAYINIEnquiryController.submitEnquiry';

import subscribeToJournal
    from '@salesforce/apex/UJJAYINIEnquiryController.subscribeToJournal';


const SUBJECTS = [
    'General Enquiry',
    'Product Information',
    'Private Viewing',
    'Order & Delivery',
    'Service & Repair',
    'Partnership',
    'Other'
];

// "Auto" theme: the footer takes the colour of the page above it.
const AUTO_THEMES = [
    { prefix: '/ujjayini/my-account', theme: 'midnight' },
    { prefix: '/ujjayini/collections', theme: 'royal' },
    { prefix: '/ujjayini/about-us', theme: 'royal' }
];

const KNOWN_THEMES = ['noir', 'midnight', 'royal', 'emerald'];


export default class UjjayiniSiteFooter extends LightningElement {

    // Set in Experience Builder: Auto, Noir, Midnight, Royal, Emerald
    @api theme = 'Auto';

    currentPath = '/ujjayini/';

    // Contact modal
    modalOpen = false;
    modalSent = false;
    isSending = false;
    formError;
    sentMessage = '';

    name = '';
    email = '';
    phone = '';
    subject = 'General Enquiry';
    message = '';
    website = '';

    // Journal
    journalEmail = '';
    journalWebsite = '';
    journalSending = false;
    journalNotice = '';
    journalError = '';

    _focusPending = false;
    _listenersAttached = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        this.currentPath = this.normalizePath(window.location.pathname);

        if (!this._listenersAttached) {
            window.addEventListener('keydown', this.handleKeydown);
            this._listenersAttached = true;
        }
    }


    renderedCallback() {

        if (!this._focusPending) {
            return;
        }

        const firstField =
            this.template.querySelector('.modal [data-field="name"]');

        if (firstField) {
            firstField.focus();
            this._focusPending = false;
        }
    }


    disconnectedCallback() {

        if (this._listenersAttached) {
            window.removeEventListener('keydown', this.handleKeydown);
            this._listenersAttached = false;
        }

        this.setBodyScrollLock(false);
    }


    @wire(CurrentPageReference)
    handlePageReference(pageReference) {

        if (pageReference) {
            this.currentPath = this.normalizePath(window.location.pathname);
        }
    }


    handleKeydown = event => {

        if (event.key === 'Escape' && this.modalOpen) {
            this.closeContact();
        }
    };


    // =========================================================
    // THEME
    // =========================================================

    get resolvedTheme() {

        const chosen = (this.theme || 'Auto').toLowerCase();

        if (chosen !== 'auto' && KNOWN_THEMES.includes(chosen)) {
            return chosen;
        }

        const match = AUTO_THEMES.find(
            entry =>
                this.currentPath === entry.prefix ||
                this.currentPath.startsWith(entry.prefix + '/')
        );

        return match ? match.theme : 'noir';
    }

    get footerClass() {
        return 'site-footer theme-' + this.resolvedTheme;
    }


    // =========================================================
    // VALUES
    // =========================================================

    get isLoggedIn() {
        return !isGuestUser;
    }

    get year() {
        return new Date().getFullYear();
    }

    get subjectOptions() {

        return SUBJECTS.map(value => ({
            key: value,
            value,
            selected: value === this.subject
        }));
    }

    get sendLabel() {
        return this.isSending ? 'SENDING' : 'SEND ENQUIRY';
    }

    get journalLabel() {
        return this.journalSending ? '···' : 'JOIN';
    }


    // =========================================================
    // CONTACT MODAL
    // =========================================================

    openContact(event) {

        const preset =
            event && event.currentTarget
                ? event.currentTarget.dataset.subject
                : null;

        this.name = '';
        this.email = '';
        this.phone = '';
        this.message = '';
        this.website = '';
        this.subject = SUBJECTS.includes(preset) ? preset : 'General Enquiry';

        this.formError = undefined;
        this.modalSent = false;
        this.modalOpen = true;
        this._focusPending = true;

        this.setBodyScrollLock(true);
    }

    closeContact() {

        if (this.isSending) {
            return;
        }

        this.modalOpen = false;
        this.setBodyScrollLock(false);
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleField(event) {

        const field = event.target.dataset.field;

        if (field) {
            this[field] = event.target.value;
            this.formError = undefined;
        }
    }

    validateForm() {

        if (this.name.trim().length < 2) {
            return 'Please enter your name.';
        }

        if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(this.email.trim())) {
            return 'Please enter a valid email address.';
        }

        const digits = this.phone.replace(/\D/g, '');

        if (this.phone.trim() && (digits.length < 10 || digits.length > 13)) {
            return 'Please enter a valid phone number.';
        }

        if (this.message.trim().length < 5) {
            return 'Please tell us a little about your enquiry.';
        }

        return null;
    }

    async sendEnquiry() {

        if (this.isSending) {
            return;
        }

        const problem = this.validateForm();

        if (problem) {
            this.formError = problem;
            return;
        }

        this.isSending = true;
        this.formError = undefined;

        try {

            const result = await submitEnquiry({
                name: this.name,
                email: this.email,
                phone: this.phone,
                subject: this.subject,
                message: this.message,
                website: this.website
            });

            this.sentMessage =
                (result && result.message) ||
                'A member of the House of UJJAYINI will be in touch.';

            this.modalSent = true;

        } catch (error) {

            this.formError = this.getErrorMessage(error);

        } finally {

            this.isSending = false;
        }
    }


    // =========================================================
    // THE JOURNAL
    // =========================================================

    handleJournalInput(event) {

        this.journalEmail = event.target.value;
        this.journalError = '';
        this.journalNotice = '';
    }

    handleJournalTrap(event) {
        this.journalWebsite = event.target.value;
    }

    handleJournalKeydown(event) {

        if (event.key === 'Enter') {
            this.joinJournal();
        }
    }

    async joinJournal() {

        if (this.journalSending) {
            return;
        }

        if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(this.journalEmail.trim())) {
            this.journalError = 'Please enter a valid email address.';
            return;
        }

        this.journalSending = true;
        this.journalError = '';

        try {

            const result = await subscribeToJournal({
                email: this.journalEmail,
                website: this.journalWebsite
            });

            this.journalNotice =
                (result && result.message) || 'Welcome to The UJJAYINI Journal.';

            this.journalEmail = '';

        } catch (error) {

            this.journalError = this.getErrorMessage(error);

        } finally {

            this.journalSending = false;
        }
    }


    // =========================================================
    // HELPERS
    // =========================================================

    scrollToTop() {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    setBodyScrollLock(locked) {

        try {
            document.body.style.overflow = locked ? 'hidden' : '';
        } catch (error) {
            // Not critical.
        }
    }

    normalizePath(path) {

        let normalized = (path || '/').split('?')[0].split('#')[0];

        if (normalized.length > 1 && normalized.endsWith('/')) {
            normalized = normalized.slice(0, -1);
        }

        return normalized;
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