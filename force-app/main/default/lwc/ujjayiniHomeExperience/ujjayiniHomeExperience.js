import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import isGuest from '@salesforce/user/isGuest';

import heroVideo from '@salesforce/resourceUrl/UJJAYINI_Product_Detail_Video';

import getFeaturedWatches
    from '@salesforce/apex/UJJAYINIFeaturedWatchesController.getFeaturedWatches';


/*
 * The three houses shown in the "Three Expressions" band.
 * key = the value the Watches page reads from ?collection=
 */
const EXPRESSIONS = [
    {
        key: 'indranila',
        number: '01',
        name: 'Indranīla',
        eyebrow: 'THE CELESTIAL COLLECTION',
        line: 'The depth of midnight. The brilliance of sapphire.',
        signature: 'SAPPHIRE · MOON · NIGHT',
        symbol: 'moon'
    },
    {
        key: 'hiranya',
        number: '02',
        name: 'Hiranya',
        eyebrow: 'THE SOVEREIGN COLLECTION',
        line: 'Gold forged into memory. Radiance made eternal.',
        signature: 'GOLD · SUN · DAWN',
        symbol: 'sun'
    },
    {
        key: 'ayas',
        number: '03',
        name: 'Ayas',
        eyebrow: 'THE ETERNAL COLLECTION',
        line: 'Steel shaped by precision. Permanence in every detail.',
        signature: 'STEEL · GEAR · ENGINE',
        symbol: 'gear'
    }
];

const TICKER = [
    'INDRANĪLA',
    'SAPPHIRE & MIDNIGHT',
    'HIRANYA',
    'GOLD & DAWN',
    'AYAS',
    'STEEL & PRECISION',
    'CERTIFICATE OF AUTHENTICITY',
    'COLLECTOR’S VAULT',
    'UJJAIN · THE MERIDIAN OF TIME'
];

/*
 * Cloudinary: ask for a smaller, modern-format image.
 * Any other URL is returned unchanged.
 */
/*
 * A Salesforce record Id (15/18 chars, e.g. a00bm00003QrMxFAAR) must
 * never be shown to customers. Returns the value only if it is real text.
 */
function readable(value) {
    if (!value) {
        return null;
    }
    const text = String(value).trim();
    return /^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$/.test(text) && /\d/.test(text) ? null : text;
}

function cloudinary(url, transform) {
    if (!url || url.indexOf('/image/upload/') === -1) {
        return url;
    }
    return url.replace('/image/upload/', '/image/upload/' + transform + '/');
}


export default class UjjayiniHomeExperience extends NavigationMixin(LightningElement) {

    watches = [];
    errorMessage;
    isLoaded = false;

    videoUrl = heroVideo;
    videoReady = false;

    _observer;
    _revealSafety;
    _pointerFrame;
    _reducedMotion = false;


    // =========================================================
    // DATA
    // =========================================================

    @wire(getFeaturedWatches)
    wiredWatches({ data, error }) {

        if (data) {

            this.watches = data.map((watch, index) => {

                const image = cloudinary(watch.imageUrl, 'f_auto,q_auto,c_limit,w_900');

                return {
                    ...watch,
                    collection: readable(watch.collection),
                    displayIndex: String(index + 1).padStart(2, '0'),
                    hasImage: !!image,
                    imageStyle: image ? 'background-image:url("' + image + '")' : '',
                    // Product Id / Product Code are never shown as text.
                    metadata: [watch.movement, watch.caseMaterial].filter(Boolean).join(' · ')
                };
            });

            this.errorMessage = undefined;
            this.isLoaded = true;

        } else if (error) {

            this.watches = [];
            // Customers never see technical errors.
            this.errorMessage = 'Featured timepieces are being prepared.';
            this.isLoaded = true;
        }
    }

    get hasWatches() {
        return this.watches.length > 0;
    }

    get showEmpty() {
        return this.isLoaded && !this.errorMessage && this.watches.length === 0;
    }

    get expressions() {
        return EXPRESSIONS.map(item => ({
            ...item,
            href: '/ujjayini/watches?collection=' + item.key,
            className: 'expression expression-' + item.key,
            isMoon: item.symbol === 'moon',
            isSun: item.symbol === 'sun',
            isGear: item.symbol === 'gear'
        }));
    }

    // Two copies so the marquee can loop without a gap.
    get tickerItems() {
        return [...TICKER, ...TICKER].map((label, index) => ({ key: 't' + index, label }));
    }


    get videoClass() {
        return this.videoReady ? 'page-video is-ready' : 'page-video';
    }


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        try {
            this._reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        } catch (e) {
            this._reducedMotion = false;
        }

        // Safety net: if the observer never fires, show everything anyway.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._revealSafety = setTimeout(() => {
            this.revealAll();
            this.videoReady = true;
        }, 3500);
    }

    renderedCallback() {

        this.observeReveals();

        // The video may already be loaded (cache) before our listener ran.
        if (!this.videoReady) {
            const video = this.template.querySelector('video');
            if (video && video.readyState >= 2) {
                this.videoReady = true;
            }
        }
    }

    disconnectedCallback() {

        clearTimeout(this._revealSafety);

        if (this._pointerFrame) {
            cancelAnimationFrame(this._pointerFrame);
        }

        if (this._observer) {
            this._observer.disconnect();
            this._observer = undefined;
        }
    }


    // =========================================================
    // VIDEO
    // =========================================================

    handleVideoReady() {
        this.videoReady = true;
    }


    // =========================================================
    // HERO POINTER PARALLAX
    // =========================================================

    handleHeroPointer(event) {

        if (this._reducedMotion || event.pointerType === 'touch') {
            return;
        }

        const hero = event.currentTarget;
        const rect = hero.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width - 0.5;
        const y = (event.clientY - rect.top) / rect.height - 0.5;

        if (this._pointerFrame) {
            cancelAnimationFrame(this._pointerFrame);
        }

        this._pointerFrame = requestAnimationFrame(() => {
            hero.style.setProperty('--mx', x.toFixed(3));
            hero.style.setProperty('--my', y.toFixed(3));
        });
    }

    handleHeroLeave(event) {
        event.currentTarget.style.setProperty('--mx', '0');
        event.currentTarget.style.setProperty('--my', '0');
    }


    // =========================================================
    // CARD TILT + GLARE
    // =========================================================

    handleCardMove(event) {

        if (this._reducedMotion || event.pointerType === 'touch') {
            return;
        }

        const card = event.currentTarget;
        const rect = card.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width;
        const y = (event.clientY - rect.top) / rect.height;

        card.style.setProperty('--rx', ((0.5 - y) * 8).toFixed(2) + 'deg');
        card.style.setProperty('--ry', ((x - 0.5) * 10).toFixed(2) + 'deg');
        card.style.setProperty('--gx', (x * 100).toFixed(1) + '%');
        card.style.setProperty('--gy', (y * 100).toFixed(1) + '%');
    }

    handleCardLeave(event) {
        const card = event.currentTarget;
        card.style.setProperty('--rx', '0deg');
        card.style.setProperty('--ry', '0deg');
    }


    // =========================================================
    // SCROLL REVEAL
    // =========================================================

    observeReveals() {

        const items = this.template.querySelectorAll('[data-reveal]:not([data-watched])');

        if (!items.length) {
            return;
        }

        if (this._reducedMotion || typeof IntersectionObserver === 'undefined') {
            items.forEach(item => item.classList.add('is-in'));
            return;
        }

        if (!this._observer) {
            this._observer = new IntersectionObserver(entries => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('is-in');
                        this._observer.unobserve(entry.target);
                    }
                });
            }, { threshold: 0.14, rootMargin: '0px 0px -6% 0px' });
        }

        items.forEach(item => {
            item.setAttribute('data-watched', 'true');
            this._observer.observe(item);
        });
    }

    revealAll() {
        this.template.querySelectorAll('[data-reveal]').forEach(item => item.classList.add('is-in'));
    }

    scrollToStory() {
        const target = this.template.querySelector('.ticker');
        if (target) {
            target.scrollIntoView({ behavior: this._reducedMotion ? 'auto' : 'smooth', block: 'start' });
        }
    }


    // =========================================================
    // NAVIGATION
    // =========================================================

    handleProductClick(event) {

        const productId = event.currentTarget.dataset.productId;

        if (!productId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Product_Detail__c' },
            state: { productId }
        });
    }

    handleEnterVault() {

        const vaultPath = '/ujjayini/collector-vault';

        const destination = isGuest
            ? '/ujjayini/login?startURL=' + encodeURIComponent(vaultPath)
            : vaultPath;

        window.location.assign(destination);
    }
}