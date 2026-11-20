import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import isGuestUser from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

import accountVideo
    from '@salesforce/resourceUrl/UJJAYINI_Craftsmanship_Video';

import getMyAccount
    from '@salesforce/apex/UJJAYINIAccountController.getMyAccount';

import updateMyDetails
    from '@salesforce/apex/UJJAYINIAccountController.updateMyDetails';

import getMyOrders
    from '@salesforce/apex/UJJAYINIOrderHistoryController.getMyOrders';


const PRICE = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
});

const DATE = new Intl.DateTimeFormat('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
});

const MONTH_YEAR = new Intl.DateTimeFormat('en-IN', {
    month: 'long',
    year: 'numeric'
});

const TIERS = ['Initiate', 'Collector', 'Connoisseur', 'Patron of Time'];

const TABS = [
    { key: 'overview', label: 'OVERVIEW' },
    { key: 'orders', label: 'ORDERS' },
    { key: 'details', label: 'MY DETAILS' }
];


export default class UjjayiniAccount extends NavigationMixin(LightningElement) {

    account;
    orders = [];

    isLoading = true;
    errorMessage;

    activeTab = 'overview';

    isEditing = false;
    isSaving = false;
    saveError;
    saveNotice;

    phone = '';
    street = '';
    city = '';
    state = '';
    postalCode = '';
    country = 'India';

    cardStyle = '';

    videoUrl = accountVideo;
    videoReady = false;
    _videoInitialized = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        if (isGuestUser) {

            window.location.href =
                this.sitePrefix +
                '/login?startURL=' +
                encodeURIComponent(window.location.pathname);

            return;
        }

        this.loadAccount();
        this.loadOrders();
    }


    renderedCallback() {

        if (this._videoInitialized) {
            return;
        }

        const video = this.template.querySelector('.bg-video');

        if (!video) {
            return;
        }

        this._videoInitialized = true;

        video.muted = true;
        video.defaultMuted = true;

        const reduceMotion =
            window.matchMedia &&
            window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        if (reduceMotion) {
            video.pause();
            return;
        }

        const playPromise = video.play();

        if (playPromise && playPromise.catch) {
            playPromise.catch(() => {
                // Autoplay blocked: the sky background stays.
            });
        }
    }


    get sitePrefix() {
        return (basePath || '/ujjayini').replace(/\/s$/i, '');
    }


    async loadAccount() {

        try {

            this.account = await getMyAccount();
            this.errorMessage = undefined;

        } catch (error) {

            this.errorMessage = this.getErrorMessage(error);

        } finally {

            this.isLoading = false;
        }
    }


    // Orders load separately so a problem there never hides the account.
    async loadOrders() {

        try {

            const data = await getMyOrders();

            this.orders = (data || []).map(order => ({
                ...order,
                formattedTotal: this.formatPrice(order.totalAmount),
                formattedDate: this.formatDate(order.effectiveDate),
                statusClass: order.isCancelled
                    ? 'status-pill is-cancelled'
                    : 'status-pill',
                itemLabel: order.itemCount === 1
                    ? '1 TIMEPIECE'
                    : order.itemCount + ' TIMEPIECES'
            }));

        } catch (error) {

            this.orders = [];
        }
    }


    // =========================================================
    // VIDEO
    // =========================================================

    handleVideoReady() {
        this.videoReady = true;
    }

    get videoClass() {
        return this.videoReady ? 'bg-video is-ready' : 'bg-video';
    }


    // =========================================================
    // VIEW STATE
    // =========================================================

    get showGuestRedirect() {
        return isGuestUser;
    }

    get showLoader() {
        return !isGuestUser && this.isLoading;
    }

    get showError() {
        return !isGuestUser && !this.isLoading && !!this.errorMessage;
    }

    get hasAccount() {
        return !!this.account;
    }

    get tabs() {

        return TABS.map(tab => ({
            ...tab,
            className: tab.key === this.activeTab ? 'tab is-active' : 'tab'
        }));
    }

    get isOverview() {
        return this.activeTab === 'overview';
    }

    get isOrders() {
        return this.activeTab === 'orders';
    }

    get isDetails() {
        return this.activeTab === 'details';
    }

    handleTab(event) {

        this.activeTab = event.currentTarget.dataset.tab;
        this.isEditing = false;
        this.saveError = undefined;
    }


    // =========================================================
    // COLLECTOR CARD + STANDING
    // =========================================================

    get greetingName() {

        if (!this.account) {
            return '';
        }

        return this.account.firstName || this.account.fullName || 'Collector';
    }

    get initials() {

        if (!this.account) {
            return 'U';
        }

        const first = (this.account.firstName || '').trim();
        const last = (this.account.lastName || '').trim();

        const letters =
            (first ? first.charAt(0) : '') +
            (last ? last.charAt(0) : '');

        return (letters || 'U').toUpperCase();
    }

    get memberSinceLabel() {

        if (!this.account || !this.account.memberSince) {
            return '';
        }

        const parsed = new Date(this.account.memberSince);

        return isNaN(parsed.getTime())
            ? String(this.account.memberSince)
            : MONTH_YEAR.format(parsed).toUpperCase();
    }

    get tierUpper() {
        return this.account ? (this.account.tierName || '').toUpperCase() : '';
    }

    get tierSteps() {

        const current = this.account ? this.account.tierIndex : 0;

        return TIERS.map((name, index) => ({
            key: name,
            label: name.toUpperCase(),
            className:
                index < current
                    ? 'tier-step is-done'
                    : index === current
                        ? 'tier-step is-current'
                        : 'tier-step'
        }));
    }

    get progressStyle() {

        const value = this.account ? (this.account.tierProgress || 0) : 0;

        return 'width: ' + Math.max(0, Math.min(100, value)) + '%;';
    }

    get nextTierLine() {

        if (!this.account || !this.account.nextTierName) {
            return 'You hold the highest standing in the House of UJJAYINI.';
        }

        const count = this.account.piecesToNextTier;

        return count + (count === 1 ? ' more timepiece' : ' more timepieces') +
            ' to ' + this.account.nextTierName + '.';
    }

    handleCardMove(event) {

        if (
            window.matchMedia &&
            window.matchMedia('(prefers-reduced-motion: reduce)').matches
        ) {
            return;
        }

        const rect = event.currentTarget.getBoundingClientRect();

        const x = (event.clientX - rect.left) / rect.width - 0.5;
        const y = (event.clientY - rect.top) / rect.height - 0.5;

        this.cardStyle =
            'transform: perspective(900px) rotateX(' + (-y * 8).toFixed(2) +
            'deg) rotateY(' + (x * 10).toFixed(2) + 'deg);' +
            '--shine-x: ' + ((x + 0.5) * 100).toFixed(0) + '%;';
    }

    handleCardLeave() {
        this.cardStyle = '';
    }


    // =========================================================
    // ORDERS
    // =========================================================

    get recentOrders() {
        return this.orders.slice(0, 3);
    }

    get hasOrders() {
        return this.orders.length > 0;
    }

    openOrder(event) {

        const orderId = event.currentTarget.dataset.orderId;

        if (!orderId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Order_Detail__c' },
            state: { c__orderId: orderId }
        });
    }

    showAllOrders() {
        this.activeTab = 'orders';
    }


    // =========================================================
    // DETAILS
    // =========================================================

    get addressLines() {

        if (!this.account || !this.account.street) {
            return [];
        }

        const lines = this.account.street
            .split('\n')
            .map(line => line.trim())
            .filter(line => line);

        const cityLine = [this.account.city, this.account.state, this.account.postalCode]
            .filter(part => part)
            .join(', ');

        if (cityLine) {
            lines.push(cityLine);
        }

        if (this.account.country) {
            lines.push(this.account.country);
        }

        return lines.map((text, index) => ({ key: 'a' + index, text }));
    }

    get hasAddress() {
        return this.addressLines.length > 0;
    }

    startEditing() {

        this.phone = this.account.phone || '';
        this.street = this.account.street || '';
        this.city = this.account.city || '';
        this.state = this.account.state || '';
        this.postalCode = this.account.postalCode || '';
        this.country = this.account.country || 'India';

        this.saveError = undefined;
        this.saveNotice = undefined;
        this.isEditing = true;
    }

    cancelEditing() {
        this.isEditing = false;
        this.saveError = undefined;
    }

    handleInput(event) {

        const field = event.target.dataset.field;

        if (field) {
            this[field] = event.target.value;
        }
    }

    async saveDetails() {

        if (this.isSaving) {
            return;
        }

        this.isSaving = true;
        this.saveError = undefined;

        try {

            this.account = await updateMyDetails({
                phone: this.phone,
                street: this.street,
                city: this.city,
                state: this.state,
                postalCode: this.postalCode,
                country: this.country
            });

            this.isEditing = false;
            this.saveNotice = 'Your details have been saved.';

        } catch (error) {

            this.saveError = this.getErrorMessage(error);

        } finally {

            this.isSaving = false;
        }
    }


    // =========================================================
    // NAVIGATION + SIGN OUT
    // =========================================================

    goTo(event) {

        const path = event.currentTarget.dataset.path;

        if (path) {
            window.location.href = this.sitePrefix + path;
        }
    }

    handleLogout() {

        window.location.href =
            this.sitePrefix +
            '/secur/logout.jsp?retUrl=' +
            encodeURIComponent(this.sitePrefix + '/');
    }


    // =========================================================
    // HELPERS
    // =========================================================

    formatPrice(value) {

        if (value === null || value === undefined) {
            return '';
        }

        return PRICE.format(Number(value));
    }

    formatDate(value) {

        if (!value) {
            return '';
        }

        const parsed = new Date(value);

        return isNaN(parsed.getTime()) ? String(value) : DATE.format(parsed);
    }

    getErrorMessage(error) {

        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'Unable to load your account.';
    }
}