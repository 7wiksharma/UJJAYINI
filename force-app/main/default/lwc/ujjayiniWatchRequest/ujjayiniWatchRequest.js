import { LightningElement, api } from 'lwc';

import isGuestUser from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

import createRequest
    from '@salesforce/apex/UJJAYINIWatchRequestController.createRequest';


const REQUEST_TYPES = [
    {
        value: 'Notify Me',
        title: 'Notify me',
        copy: 'Hear from us the moment it is available.',
        icon: 'M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z M10 20a2 2 0 0 0 4 0'
    },
    {
        value: 'Pre-Order',
        title: 'Pre-order',
        copy: 'Reserve your piece from the next allocation.',
        icon: 'M4 6h16v14H4z M4 10h16 M8 3v5 M16 3v5'
    },
    {
        value: 'Custom Request',
        title: 'Custom request',
        copy: 'A strap, an engraving, a private viewing.',
        icon: 'M12 3l2 7 7 2-7 2-2 7-2-7-7-2 7-2z'
    }
];

const QUICK_NOTES = [
    'A gift for someone special',
    'A private viewing, please',
    'A specific strap or bracelet',
    'Engraving on the case back'
];

const MAX_QUANTITY = 5;
const MAX_NOTE = 1000;

const FRIENDLY_ERROR =
    'We could not send your request just now. Please try again in a moment.';


export default class UjjayiniWatchRequest extends LightningElement {

    @api watchId;

    requestType = 'Notify Me';
    requestedQuantity = 1;
    customerNote = '';

    isSubmitting = false;
    isSent = false;

    successMessage;
    errorMessage;


    // =========================================================
    // VIEW DATA
    // =========================================================

    get isGuest() {
        return isGuestUser;
    }

    get isMember() {
        return !isGuestUser;
    }

    get sitePrefix() {
        return (basePath || '/ujjayini').replace(/\/s$/i, '');
    }

    get typeCards() {

        return REQUEST_TYPES.map(type => ({
            ...type,
            isSelected: type.value === this.requestType,
            pressed: type.value === this.requestType ? 'true' : 'false',
            className: type.value === this.requestType
                ? 'type-card is-selected'
                : 'type-card'
        }));
    }

    get quickNotes() {
        return QUICK_NOTES.map(text => ({ key: text, text }));
    }

    get showQuantity() {
        return this.requestType !== 'Notify Me';
    }

    get cannotDecrease() {
        return this.requestedQuantity <= 1;
    }

    get cannotIncrease() {
        return this.requestedQuantity >= MAX_QUANTITY;
    }

    get noteCount() {
        return (this.customerNote || '').length + ' / ' + MAX_NOTE;
    }

    get maxNote() {
        return MAX_NOTE;
    }

    get submitLabel() {
        return this.isSubmitting ? 'SENDING TO THE HOUSE' : 'SEND MY REQUEST';
    }


    // =========================================================
    // HANDLERS
    // =========================================================

    selectType(event) {
        this.requestType = event.currentTarget.dataset.value;
        this.clearMessages();
    }

    decrease() {
        if (!this.cannotDecrease) {
            this.requestedQuantity -= 1;
        }
    }

    increase() {
        if (!this.cannotIncrease) {
            this.requestedQuantity += 1;
        }
    }

    handleNoteChange(event) {
        this.customerNote = (event.target.value || '').slice(0, MAX_NOTE);
        this.clearMessages();
    }

    addQuickNote(event) {

        const text = event.currentTarget.dataset.text;

        if (!text || this.customerNote.includes(text)) {
            return;
        }

        const joined = this.customerNote.trim()
            ? this.customerNote.trim() + '. ' + text
            : text;

        this.customerNote = joined.slice(0, MAX_NOTE);
    }

    async handleSubmit() {

        this.clearMessages();

        if (!this.watchId) {
            this.errorMessage = 'We could not identify this timepiece. Please reload the page.';
            return;
        }

        this.isSubmitting = true;

        try {

            const result = await createRequest({
                watchId: this.watchId,
                requestType: this.requestType,
                requestedQuantity: this.showQuantity ? this.requestedQuantity : 1,
                customerNote: this.customerNote
            });

            this.successMessage =
                (result && result.message) ||
                'Your request has been received.';

            this.isSent = true;
            this.customerNote = '';
            this.requestedQuantity = 1;

        } catch (error) {

            this.errorMessage = this.getErrorMessage(error);

        } finally {

            this.isSubmitting = false;
        }
    }

    startAnother() {
        this.isSent = false;
        this.requestType = 'Notify Me';
        this.clearMessages();
    }

    goToLogin() {
        window.location.href =
            this.sitePrefix + '/login?startURL=' +
            encodeURIComponent(window.location.pathname + window.location.search);
    }

    goToRegister() {
        window.location.href = this.sitePrefix + '/SelfRegister';
    }

    clearMessages() {
        this.successMessage = undefined;
        this.errorMessage = undefined;
    }

    /*
     * Our own validation messages are shown; technical ones never are.
     */
    getErrorMessage(error) {

        const raw =
            (error && error.body && error.body.message) ||
            (error && error.message) ||
            '';

        if (!raw || /apex|script-thrown|exception|System\.|invalid id/i.test(raw)) {
            return FRIENDLY_ERROR;
        }

        return raw;
    }
}