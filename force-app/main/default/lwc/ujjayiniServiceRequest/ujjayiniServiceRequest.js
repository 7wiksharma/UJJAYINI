import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import isGuestUser from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

import createRequest
    from '@salesforce/apex/UJJAYINIServiceRequestController.createRequest';

import getMyAssets
    from '@salesforce/apex/UJJAYINICollectorVaultController.getMyAssets';


const SERVICE_TYPES = [
    'Repair',
    'Maintenance',
    'Inspection',
    'Warranty Claim',
    'Replacement',
    'Other'
];

const PRIORITIES = ['Low', 'Medium', 'High', 'Urgent'];

const FRIENDLY_ERROR =
    'We could not send your request just now. Please try again in a moment, ' +
    'or write to us through the Concierge at the foot of the page.';

// The six services of the atelier (value = the Service_Type__c value).
const SERVICES = [
    {
        value: 'Maintenance',
        number: '01',
        title: 'Complete Service',
        copy: 'The movement is taken apart, cleaned, lubricated and timed again, so your watch keeps the time it was made to keep.',
        icon: 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z M12 7v5l3 2'
    },
    {
        value: 'Repair',
        number: '02',
        title: 'Repair',
        copy: 'From a stopped movement to a marked case, our watchmakers restore what time has worn away.',
        icon: 'M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z'
    },
    {
        value: 'Inspection',
        number: '03',
        title: 'Inspection & Timing',
        copy: 'A precise check of accuracy, water resistance and power reserve, with an honest account of what we find.',
        icon: 'M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13z M15.5 15.5L21 21'
    },
    {
        value: 'Warranty Claim',
        number: '04',
        title: 'Warranty Care',
        copy: 'Is your timepiece within its UJJAYINI warranty? We take care of the claim, from inspection to repair.',
        icon: 'M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z M9 12l2 2 4-4'
    },
    {
        value: 'Replacement',
        number: '05',
        title: 'Parts & Straps',
        copy: 'Crystals, crowns, straps and bracelets, replaced with parts made for your UJJAYINI timepiece.',
        icon: 'M4 12a8 8 0 0 1 14-5.3L20 9 M20 4v5h-5 M20 12a8 8 0 0 1-14 5.3L4 15 M4 20v-5h5'
    },
    {
        value: 'Other',
        number: '06',
        title: 'Bespoke Request',
        copy: 'Polishing, engraving, or anything else your timepiece deserves. Tell us, and we will listen.',
        icon: 'M12 3l2 7 7 2-7 2-2 7-2-7-7-2 7-2z'
    }
];

const JOURNEY = [
    { number: '01', title: 'Your request', copy: 'Tell us what your timepiece needs. Your request reaches the atelier at once.' },
    { number: '02', title: 'We confirm', copy: 'A member of the House reviews your request and confirms the next steps with you.' },
    { number: '03', title: 'Into the atelier', copy: 'Your watch is received, recorded against your Collector\'s Vault and examined.' },
    { number: '04', title: 'The work', copy: 'Our watchmakers carry out the service, one careful step at a time.' },
    { number: '05', title: 'The final check', copy: 'Accuracy, finish and water resistance are tested before it leaves us.' },
    { number: '06', title: 'Back to you', copy: 'Your timepiece returns to your wrist, and the service is kept in its history.' }
];


export default class UjjayiniServiceRequest extends LightningElement {

    // Form
    serviceType = 'Repair';
    priority = 'Medium';
    description = '';
    assetId = '';

    assets = [];
    requestedAssetId;

    isSubmitting = false;
    isSent = false;
    successMessage;
    errorMessage;

    // Scroll story
    isCompact = false;
    activeStep = 0;

    _distance = 0;
    _ticking = false;
    _measured = false;
    _jsPin = false;
    _listening = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        if (!isGuestUser) {
            this.loadAssets();
        }

        this.isCompact = this.checkCompact();

        if (!this._listening) {
            window.addEventListener('scroll', this.handleScroll, { passive: true });
            window.addEventListener('resize', this.handleResize);
            this._listening = true;
        }
    }

    renderedCallback() {

        if (this._measured) {
            return;
        }

        this._measured = true;

        // Wait one frame so the track has its final width.
        requestAnimationFrame(() => {
            this.measure();
            this.update();
        });
    }

    disconnectedCallback() {

        if (this._listening) {
            window.removeEventListener('scroll', this.handleScroll);
            window.removeEventListener('resize', this.handleResize);
            this._listening = false;
        }
    }


    // =========================================================
    // WATCH PASSED FROM THE COLLECTOR VAULT (?assetId=...)
    // Preselected only when it is one of the customer's own
    // timepieces. The server validates ownership again.
    // =========================================================

    @wire(CurrentPageReference)
    getPageReference(pageReference) {

        let requested;

        if (pageReference && pageReference.state) {
            requested = pageReference.state.assetId || pageReference.state.c__assetId;
        }

        if (!requested) {
            try {
                requested = new URLSearchParams(window.location.search).get('assetId');
            } catch (error) {
                requested = undefined;
            }
        }

        if (requested) {
            this.requestedAssetId = requested;
            this.applyRequestedAsset();
        }
    }

    async loadAssets() {

        try {
            this.assets = (await getMyAssets()) || [];
            this.applyRequestedAsset();
        } catch (error) {
            // The timepiece selector is optional.
            this.assets = [];
        }
    }

    applyRequestedAsset() {

        if (!this.requestedAssetId || this.assetId) {
            return;
        }

        const owned = this.assets.find(asset => asset.assetId === this.requestedAssetId);

        if (owned) {
            this.assetId = owned.assetId;
        }
    }


    // =========================================================
    // SCROLL STORY
    // =========================================================

    checkCompact() {

        const small = window.matchMedia && window.matchMedia('(max-width: 820px)').matches;
        const calm = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        return !!(small || calm);
    }

    handleScroll = () => {

        if (this._ticking) {
            return;
        }

        this._ticking = true;

        requestAnimationFrame(() => {
            this._ticking = false;
            this.update();
        });
    };

    handleResize = () => {
        this.isCompact = this.checkCompact();
        this.measure();
        this.update();
    };

    measure() {

        const section = this.template.querySelector('.services-scroll');
        const track = this.template.querySelector('.services-track');

        if (!section || !track) {
            return;
        }

        if (this.isCompact) {
            section.style.height = '';
            this._distance = 0;
            return;
        }

        this._distance = Math.max(0, track.scrollWidth - window.innerWidth);

        // Vertical scroll room equals the horizontal travel.
        section.style.height = (this._distance + window.innerHeight) + 'px';

        const journey = this.template.querySelector('.journey-scroll');

        if (journey) {
            journey.style.height = (window.innerHeight * 3.2) + 'px';
        }
    }

    update() {

        const vh = window.innerHeight;

        this.updateServices(vh);
        this.updateJourney(vh);
    }

    updateServices(vh) {

        const section = this.template.querySelector('.services-scroll');
        const stage = this.template.querySelector('.services-stage');
        const track = this.template.querySelector('.services-track');

        if (!section || !stage || !track) {
            return;
        }

        if (this.isCompact) {
            this.resetStyles([stage, track]);
            return;
        }

        const rect = section.getBoundingClientRect();
        const progress = this.progressOf(rect, vh);

        this.pin(section, stage, rect, vh);

        track.style.transform = 'translate3d(' + (-progress * this._distance).toFixed(1) + 'px,0,0)';

        const bigText = this.template.querySelector('.big-text');

        if (bigText) {
            const travel = Math.max(0, bigText.scrollWidth - window.innerWidth * 0.6);
            bigText.style.transform = 'translate3d(' + (-progress * travel).toFixed(1) + 'px,0,0)';
        }

        const fill = this.template.querySelector('.services-progress-fill');

        if (fill) {
            fill.style.transform = 'scaleX(' + progress.toFixed(3) + ')';
        }

        // The watch keeps time as the visitor scrolls.
        this.rotate('.atelier-watch .hand-minute', 60 + progress * 1080);
        this.rotate('.atelier-watch .hand-hour', 300 + progress * 90);
        this.rotate('.atelier-watch .bezel-marks', -progress * 120);
    }

    updateJourney(vh) {

        const section = this.template.querySelector('.journey-scroll');
        const stage = this.template.querySelector('.journey-stage');

        if (!section || !stage) {
            return;
        }

        if (this.isCompact) {
            this.resetStyles([stage]);
            section.style.height = '';
            return;
        }

        const rect = section.getBoundingClientRect();
        const progress = this.progressOf(rect, vh);

        this.pin(section, stage, rect, vh);

        const road = this.template.querySelector('.road');
        const watch = this.template.querySelector('.road-watch');
        const lines = this.template.querySelector('.road-lines');

        if (road && watch) {
            const travel = Math.max(0, road.clientHeight - watch.clientHeight);
            watch.style.transform = 'translate3d(-50%,' + (progress * travel).toFixed(1) + 'px,0)';
        }

        if (lines) {
            lines.style.backgroundPosition = '0 ' + (progress * 900).toFixed(0) + 'px';
        }

        const step = Math.min(JOURNEY.length - 1, Math.floor(progress * JOURNEY.length));

        if (step !== this.activeStep) {
            this.activeStep = step;
        }
    }

    progressOf(rect, vh) {

        const travel = rect.height - vh;

        if (travel <= 0) {
            return 0;
        }

        return Math.min(1, Math.max(0, -rect.top / travel));
    }

    /*
     * Pins the stage with CSS sticky. If a parent of the page
     * blocks sticky, the stage is pinned with a transform instead.
     */
    pin(section, stage, rect, vh) {

        const travel = Math.max(0, rect.height - vh);
        const offset = Math.min(Math.max(-rect.top, 0), travel);

        if (!this._jsPin && rect.top < -10 && rect.bottom > vh + 10) {

            const stageTop = stage.getBoundingClientRect().top;

            if (Math.abs(stageTop) > 6) {
                this._jsPin = true;
            }
        }

        if (this._jsPin) {
            stage.style.position = 'absolute';
            stage.style.top = '0';
            stage.style.left = '0';
            stage.style.right = '0';
            stage.style.transform = 'translate3d(0,' + offset.toFixed(1) + 'px,0)';
        }
    }

    rotate(selector, degrees) {

        const element = this.template.querySelector(selector);

        if (element) {
            element.setAttribute('transform', 'rotate(' + degrees.toFixed(1) + ' 100 130)');
        }
    }

    resetStyles(elements) {

        elements.forEach(element => {
            element.style.position = '';
            element.style.top = '';
            element.style.left = '';
            element.style.right = '';
            element.style.transform = '';
        });
    }


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

    get loginUrl() {
        return this.sitePrefix + '/login?startURL=' +
            encodeURIComponent(this.sitePrefix + '/service');
    }

    get registerUrl() {
        return this.sitePrefix + '/SelfRegister';
    }

    get services() {
        return SERVICES;
    }

    get journeySteps() {

        return JOURNEY.map((step, index) => {

            let className = 'step';

            if (this.isCompact) {
                className += ' is-active';
            } else if (index === this.activeStep) {
                className += ' is-active';
            } else if (index < this.activeStep) {
                className += ' is-past';
            }

            return { ...step, key: step.number, className };
        });
    }

    get stepCounter() {
        return '0' + (this.activeStep + 1) + ' / 0' + JOURNEY.length;
    }

    get showAssetSelector() {
        return this.assets.length > 0;
    }

    get assetOptions() {

        const options = [{
            key: 'none',
            label: 'No specific timepiece',
            value: '',
            selected: !this.assetId
        }];

        this.assets.forEach(asset => {

            const purchased = asset.purchaseDate ? ' · purchased ' + asset.purchaseDate : '';

            options.push({
                key: asset.assetId,
                label: asset.productName + purchased,
                value: asset.assetId,
                selected: asset.assetId === this.assetId
            });
        });

        return options;
    }

    get serviceTypeOptions() {

        return SERVICE_TYPES.map(value => {

            const service = SERVICES.find(item => item.value === value);

            return {
                key: value,
                label: service ? service.title : value,
                value,
                selected: value === this.serviceType
            };
        });
    }

    get priorityOptions() {

        return PRIORITIES.map(value => ({
            key: value,
            label: value,
            value,
            selected: value === this.priority
        }));
    }

    get submitLabel() {
        return this.isSubmitting ? 'SENDING TO THE ATELIER' : 'SUBMIT SERVICE REQUEST';
    }

 goToLogin() {
        window.location.href = this.loginUrl;
    }

    goToRegister() {
        window.location.href = this.registerUrl;
    }
    // =========================================================
    // ACTIONS
    // =========================================================

    scrollToForm() {

        const form = this.template.querySelector('.request-section');

        if (form) {
            form.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    chooseService(event) {

        const value = event.currentTarget.dataset.value;

        if (SERVICE_TYPES.includes(value)) {
            this.serviceType = value;
        }

        this.isSent = false;
        this.clearMessages();
        this.scrollToForm();
    }

    handleAssetChange(event) {
        this.assetId = event.target.value;
        this.clearMessages();
    }

    handleServiceTypeChange(event) {
        this.serviceType = event.target.value;
        this.clearMessages();
    }

    handlePriorityChange(event) {
        this.priority = event.target.value;
        this.clearMessages();
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
        this.clearMessages();
    }

    async handleSubmit() {

        this.clearMessages();

        if (!this.description || !this.description.trim()) {
            this.errorMessage = 'Please tell us a little about the service you need.';
            return;
        }

        this.isSubmitting = true;

        try {

            const result = await createRequest({
                serviceType: this.serviceType,
                priority: this.priority,
                description: this.description,
                assetId: this.assetId || null
            });

            this.successMessage =
                (result && result.message) ||
                'Your service request has been received.';

            this.isSent = true;
            this.description = '';
            this.serviceType = 'Repair';
            this.priority = 'Medium';

            // Lets other components (such as the history) refresh.
            window.dispatchEvent(new CustomEvent('ujjayini:servicerequest'));

        } catch (error) {

            this.errorMessage = this.getErrorMessage(error);

        } finally {

            this.isSubmitting = false;
        }
    }

    startAnother() {
        this.isSent = false;
        this.clearMessages();
    }

    clearMessages() {
        this.successMessage = undefined;
        this.errorMessage = undefined;
    }

    /*
     * Shows our own validation messages, but never a technical one.
     */
    getErrorMessage(error) {

        const raw =
            (error && error.body && error.body.message) ||
            (error && error.message) ||
            '';

        if (
            !raw ||
            /apex|script-thrown|exception|System\.|invalid id|null/i.test(raw)
        ) {
            return FRIENDLY_ERROR;
        }

        return raw;
    }
}