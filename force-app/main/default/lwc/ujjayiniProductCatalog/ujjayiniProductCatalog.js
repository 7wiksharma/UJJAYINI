import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import isGuestUser from '@salesforce/user/isGuest';

import getProducts
    from '@salesforce/apex/UJJAYINIProductCatalogController.getProducts';

import addToCart
    from '@salesforce/apex/UJJAYINICartController.addToCart';

import getWishlistItems
    from '@salesforce/apex/UJJAYINIWishlistController.getWishlistItems';

import addToWishlist
    from '@salesforce/apex/UJJAYINIWishlistController.addToWishlist';

import removeFromWishlist
    from '@salesforce/apex/UJJAYINIWishlistController.removeFromWishlist';

import pantherVideo
    from '@salesforce/resourceUrl/UJJAYINI_BlackPanther';


// =========================================================
// CONFIG
// =========================================================

const COLLECTIONS = [
    {
        key: 'indranila',
        match: 'indranila',
        label: 'INDRANĪLA',
        number: '01',
        eyebrow: 'THE CELESTIAL COLLECTION',
        title: 'Indranīla',
        tagline: 'The depth of midnight. The brilliance of sapphire.',
        signature: 'SAPPHIRE · MIDNIGHT'
    },
    {
        key: 'hiranya',
        match: 'hiranya',
        label: 'HIRANYA',
        number: '02',
        eyebrow: 'THE SOVEREIGN COLLECTION',
        title: 'Hiranya',
        tagline: 'Gold forged into memory. Radiance made eternal.',
        signature: 'GOLD · DAWN'
    },
    {
        key: 'ayas',
        match: 'ayas',
        label: 'AYAS',
        number: '03',
        eyebrow: 'THE ETERNAL COLLECTION',
        title: 'Ayas',
        tagline: 'Steel shaped by precision. Permanence in every detail.',
        signature: 'STEEL · ETERNAL'
    }
];

// The crown dial: ALL + the three collections.
const DIAL = [
    { value: 'ALL', label: 'ALL' },
    ...COLLECTIONS.map(c => ({ value: c.key, label: c.label }))
];

const DIAL_STEP = 26;

const FACETS = [
    { key: 'movement', label: 'MOVEMENT' },
    { key: 'caseMaterial', label: 'CASE' },
    { key: 'strapMaterial', label: 'STRAP' },
    { key: 'dialColor', label: 'DIAL' },
    { key: 'waterResistance', label: 'WATER RESISTANCE' }
];

const SORTS = [
    { value: 'featured', label: 'FEATURED' },
    { value: 'price-low', label: 'PRICE ↑' },
    { value: 'price-high', label: 'PRICE ↓' },
    { value: 'name', label: 'A – Z' }
];

// "Find my watch" moods: one tap, several ideas at once.
const MOODS = [
    {
        key: 'golden',
        label: 'BOLD & GOLDEN',
        test: p => /gold/i.test(p.caseMaterial || '') || norm(p.collectionName) === 'hiranya'
    },
    {
        key: 'midnight',
        label: 'DEEP & MIDNIGHT',
        test: p => norm(p.collectionName) === 'indranila' || /blue|black|sapphire|midnight/i.test(p.dialColor || '')
    },
    {
        key: 'steel',
        label: 'EVERYDAY STEEL',
        test: p => norm(p.collectionName) === 'ayas' || /steel|titanium/i.test(p.caseMaterial || '')
    },
    {
        key: 'rare',
        label: "COLLECTOR'S RARITY",
        test: p => p.limitedEdition === true
    },
    {
        key: 'gift',
        label: 'UNDER ₹1 LAKH',
        test: p => p.price > 0 && p.price < 100000
    }
];

const COMPARE_ROWS = [
    ['COLLECTION', 'collectionName'],
    ['BRAND', 'brand'],
    ['MOVEMENT', 'movement'],
    ['CASE', 'caseMaterial'],
    ['STRAP', 'strapMaterial'],
    ['DIAL', 'dialColor'],
    ['WATER RESISTANCE', 'waterResistance'],
    ['EDITION', 'editionLabel'],
    ['WARRANTY', 'warrantyLabel'],
    ['MODEL', 'modelNumber'],
    ['REFERENCE', 'productCode']
];

const PRICE_STEP = 5000;
const HISTOGRAM_BARS = 14;
const MAX_COMPARE = 3;
const DRAG_THRESHOLD = 8;
const LOUPE_ZOOM = 2.5;
const LOUPE_RADIUS = 90;

const FRIENDLY_ERROR =
    'Something interrupted the moment. Please try again.';

const INR = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });


function norm(value) {
    return (value || '')
        .toString()
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .toLowerCase()
        .trim();
}

// Cloudinary delivers a smaller, modern-format image when
// transformations are added right after "/upload/".
function cloudinary(url, transform) {

    if (!url || url.indexOf('res.cloudinary.com') === -1 || url.indexOf('/upload/') === -1) {
        return url;
    }

    return url.replace('/upload/', '/upload/' + transform + '/');
}

function tagline(description) {

    if (!description) {
        return '';
    }

    const clean = description.replace(/\s+/g, ' ').trim();
    const match = clean.match(/^.*?[.!?](\s|$)/);
    const sentence = (match ? match[0] : clean).trim();
    const line = sentence.length <= 86 ? sentence : sentence.slice(0, 84).replace(/\s+\S*$/, '') + '…';

    return line;
}


export default class UjjayiniProductCatalog
    extends NavigationMixin(LightningElement) {

    // =========================================================
    // STATE
    // =========================================================

    products = [];
    error;
    isLoading = true;
    retryCount = 0;

    // Filters
    activeCollection = 'ALL';
    sortBy = 'featured';
    priceLow;
    priceHigh;
    selected = {};
    limitedOnly = false;
    inStockOnly = false;
    activeMood;
    searchText = '';
    searchTerm = '';

    refineOpen = false;

    // Cards
    loadedImages = {};
    pulseId;

    // Instruments
    loupeOn = false;

    // Compare
    compareIds = [];
    compareOpen = false;
    dragId;
    dragImage;
    overDock = false;

    // Video
    videoReady = false;

    // Notification
    showNotification = false;
    notificationType = '';
    notificationTitle = '';
    notificationMessage = '';

    // Guest
    showGuestCartModal = false;

    _notificationTimer;
    _videoInitialized = false;
    _observer;
    _scrollFrame;
    _wheelAccumulator = 0;
    _lastWheel = 0;
    _crownDrag;
    _pending;
    _justDragged = false;
    _pulseTimer;
    _searchTimer;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        this.preconnectImages();

        this.applyCollectionFromUrl();

        this.loadProducts();

        window.addEventListener('pageshow', this.handlePageShow);
        window.addEventListener('ujjayini:wishlistchange', this.handleWishlistChange);
        window.addEventListener('scroll', this.handleScroll, { passive: true });
        window.addEventListener('resize', this.handleScroll, { passive: true });
    }

    disconnectedCallback() {

        clearTimeout(this._notificationTimer);
        clearTimeout(this._pulseTimer);
        clearTimeout(this._searchTimer);

        window.removeEventListener('pageshow', this.handlePageShow);
        window.removeEventListener('ujjayini:wishlistchange', this.handleWishlistChange);
        window.removeEventListener('scroll', this.handleScroll);
        window.removeEventListener('resize', this.handleScroll);

        this.stopDragListeners();
        this.clearPending();

        if (this._observer) {
            this._observer.disconnect();
            this._observer = undefined;
        }

        if (this._scrollFrame) {
            cancelAnimationFrame(this._scrollFrame);
        }
    }

    renderedCallback() {

        this.initVideo();
        this.observeReveals();
        this.handleScroll();
    }

    handlePageShow = event => {
        if (event.persisted) {
            this.loadProducts();
        }
    };

    handleWishlistChange = () => {
        this.loadWishlist();
    };

    // /ujjayini/watches?collection=hiranya opens with the crown on Hiranya.
    applyCollectionFromUrl() {

        try {

            const value = new URLSearchParams(window.location.search).get('collection');
            const key = norm(value);
            const match = COLLECTIONS.find(c => c.key === key || c.match === key);

            if (match) {
                this.activeCollection = match.key;

                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this.handleScrollToCatalog(), 700);
            }

        } catch (e) {
            // Without the parameter the page simply shows everything.
        }
    }

    preconnectImages() {

        try {

            if (document.querySelector('link[data-ujjayini-preconnect]')) {
                return;
            }

            const link = document.createElement('link');
            link.rel = 'preconnect';
            link.href = 'https://res.cloudinary.com';
            link.crossOrigin = 'anonymous';
            link.setAttribute('data-ujjayini-preconnect', 'true');
            document.head.appendChild(link);

        } catch (e) {
            // Optional speed-up only.
        }
    }


    // =========================================================
    // VIDEO + SCROLL (parallax, fade, sticky rail)
    // =========================================================

    get pantherVideoUrl() {
        return pantherVideo;
    }

    get videoClass() {
        return this.videoReady ? 'panther-video is-ready' : 'panther-video';
    }

    handleVideoReady() {
        this.videoReady = true;
    }

    initVideo() {

        if (this._videoInitialized) {
            return;
        }

        const video = this.template.querySelector('video');

        if (!video) {
            return;
        }

        this._videoInitialized = true;
        video.muted = true;
        video.defaultMuted = true;

        if (this.reduceMotion) {
            this.videoReady = true;
            return;
        }

        const playing = video.play();

        if (playing && playing.catch) {
            playing.catch(() => {
                this.videoReady = true;
            });
        }
    }

    get reduceMotion() {
        return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    }

    handleScroll = () => {

        if (this._scrollFrame) {
            return;
        }

        this._scrollFrame = requestAnimationFrame(() => {

            this._scrollFrame = undefined;

            const stage = this.template.querySelector('.video-stage');
            const viewport = window.innerHeight || 800;
            const progress = Math.min(1, Math.max(0, (window.scrollY || 0) / (viewport * 0.9)));

            if (stage) {
                stage.style.setProperty('--p', progress.toFixed(3));
            }

            this.pinRail();
        });
    };

    // Rail stays beside the timepieces. Done in JS because the
    // site container can stop CSS "position: sticky" from working.
    pinRail() {

        const rail = this.template.querySelector('.rail');
        const workspace = this.template.querySelector('.catalog-workspace');

        if (!rail || !workspace) {
            return;
        }

        if (window.innerWidth <= 1000) {
            rail.style.transform = '';
            return;
        }

        const top = 104;
        const area = workspace.getBoundingClientRect();
        const railHeight = rail.offsetHeight;
        const max = Math.max(0, area.height - railHeight - 40);
        const offset = Math.min(max, Math.max(0, top - area.top));

        rail.style.transform = 'translate3d(0,' + offset.toFixed(1) + 'px,0)';
    }

    observeReveals() {

        const elements = this.template.querySelectorAll('.reveal:not([data-watched])');

        if (!elements.length) {
            return;
        }

        if (!('IntersectionObserver' in window) || this.reduceMotion) {
            elements.forEach(el => {
                el.setAttribute('data-watched', 'true');
                el.classList.add('is-in');
            });
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
            }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
        }

        elements.forEach(el => {
            el.setAttribute('data-watched', 'true');
            this._observer.observe(el);
        });
    }


    // =========================================================
    // LOAD
    // Products render first; the wishlist arrives afterwards and
    // never blocks or hides the catalog.
    // =========================================================

    async loadProducts() {

        this.isLoading = this.products.length === 0;
        this.error = undefined;

        try {

            const data = await getProducts();
            const wished = new Set(this.products.filter(p => p.isWishlisted).map(p => p.productId));

            this.products = (data || []).map((product, index) => ({
                ...product,
                isAddingToCart: false,
                isAddingToWishlist: false,
                isWishlisted: wished.has(product.productId),
                displayIndex: String(index + 1).padStart(2, '0'),
                order: index
            }));

            this.retryCount = 0;
            this.resetPriceBounds();

        } catch (error) {

            this.products = [];
            this.error = error;

            if (this.retryCount < 3) {
                this.retryCount++;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this.loadProducts(), 1000);
            }

        } finally {

            this.isLoading = false;
        }

        this.loadWishlist();
    }

    async loadWishlist() {

        if (isGuestUser || !this.products.length) {
            return;
        }

        try {

            const items = await getWishlistItems();
            const ids = new Set((items || []).map(item => item.productId));

            this.products = this.products.map(product => ({
                ...product,
                isWishlisted: ids.has(product.productId)
            }));

        } catch (e) {
            // Hearts simply stay empty.
        }
    }


    // =========================================================
    // PRICE BOUNDS
    // =========================================================

    get priceFloor() {

        const prices = this.products.map(p => p.price).filter(p => p > 0);

        return prices.length
            ? Math.floor(Math.min(...prices) / PRICE_STEP) * PRICE_STEP
            : 0;
    }

    get priceCeil() {

        const prices = this.products.map(p => p.price).filter(p => p > 0);

        return prices.length
            ? Math.ceil(Math.max(...prices) / PRICE_STEP) * PRICE_STEP
            : 0;
    }

    resetPriceBounds() {
        this.priceLow = this.priceFloor;
        this.priceHigh = this.priceCeil;
    }

    get hasPriceRange() {
        return this.priceCeil > this.priceFloor;
    }

    get priceStep() {
        return PRICE_STEP;
    }

    get priceLowLabel() {
        return '₹' + INR.format(this.priceLow || 0);
    }

    get priceHighLabel() {
        return '₹' + INR.format(this.priceHigh || 0);
    }

    get priceTrackStyle() {

        const span = (this.priceCeil - this.priceFloor) || 1;
        const left = ((this.priceLow - this.priceFloor) / span) * 100;
        const right = ((this.priceHigh - this.priceFloor) / span) * 100;

        return 'left:' + left.toFixed(2) + '%;width:' + Math.max(0, right - left).toFixed(2) + '%;';
    }

    get priceBars() {

        const floor = this.priceFloor;
        const span = (this.priceCeil - floor) || 1;
        const counts = new Array(HISTOGRAM_BARS).fill(0);

        this.products.forEach(product => {
            if (product.price > 0) {
                const slot = Math.min(HISTOGRAM_BARS - 1, Math.floor(((product.price - floor) / span) * HISTOGRAM_BARS));
                counts[slot]++;
            }
        });

        const max = Math.max(1, ...counts);

        return counts.map((count, index) => {

            const start = floor + (span / HISTOGRAM_BARS) * index;
            const end = start + span / HISTOGRAM_BARS;
            const inRange = end >= this.priceLow && start <= this.priceHigh;

            return {
                key: 'bar' + index,
                style: 'height:' + (count ? 18 + (count / max) * 82 : 6) + '%;',
                className: inRange ? 'bar is-in' : 'bar'
            };
        });
    }

    handlePriceLow(event) {
        const value = Number(event.target.value);
        this.priceLow = Math.min(value, this.priceHigh);
    }

    handlePriceHigh(event) {
        const value = Number(event.target.value);
        this.priceHigh = Math.max(value, this.priceLow);
    }

    get isPriceFiltered() {
        return this.hasPriceRange && (this.priceLow > this.priceFloor || this.priceHigh < this.priceCeil);
    }


    // =========================================================
    // FILTERING
    // =========================================================

    passes(product, skipFacet) {

        if (this.searchTerm && !this.matchesSearch(product)) {
            return false;
        }

        if (this.activeCollection !== 'ALL' && norm(product.collectionName) !== this.activeCollection) {
            return false;
        }

        if (this.isPriceFiltered && product.price > 0 &&
            (product.price < this.priceLow || product.price > this.priceHigh)) {
            return false;
        }

        if (this.limitedOnly && !product.limitedEdition) {
            return false;
        }

        if (this.inStockOnly && product.stockStatus === 'OUT_OF_STOCK') {
            return false;
        }

        if (this.activeMood) {
            const mood = MOODS.find(m => m.key === this.activeMood);
            if (mood && !mood.test(product)) {
                return false;
            }
        }

        for (const facet of FACETS) {

            if (facet.key === skipFacet) {
                continue;
            }

            const chosen = this.selected[facet.key];

            if (chosen && chosen.length && !chosen.includes(product[facet.key])) {
                return false;
            }
        }

        return true;
    }

    // =========================================================
    // SEARCH
    // =========================================================

    /*
     * Every word typed must appear somewhere in the watch's
     * name, collection or specs ("gold auto" finds gold automatics).
     */
    matchesSearch(product) {

        const haystack = norm([
            product.productName,
            product.collectionName,
            product.brand,
            product.movement,
            product.caseMaterial,
            product.strapMaterial,
            product.dialColor,
            product.description
        ].filter(value => value).join(' '));

        return this.searchTerm
            .split(' ')
            .filter(word => word)
            .every(word => haystack.includes(word));
    }

    handleSearchInput(event) {

        const value = event.target.value || '';
        this.searchText = value;

        clearTimeout(this._searchTimer);

        // Debounce: filter once the visitor pauses typing.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => {
            this.searchTerm = norm(value).replace(/\s+/g, ' ').trim();
        }, 250);
    }

    handleSearchKey(event) {
        if (event.key === 'Escape') {
            this.clearSearch();
        }
    }

    clearSearch() {
        clearTimeout(this._searchTimer);
        this.searchText = '';
        this.searchTerm = '';
    }

    get hasSearchText() {
        return this.searchText.length > 0;
    }

    get searchClass() {
        return this.searchText ? 'search is-active' : 'search';
    }

    get filteredProducts() {

        const result = this.products.filter(product => this.passes(product));

        result.sort((a, b) => {

            if (this.sortBy === 'price-low') {
                return (a.price || 0) - (b.price || 0);
            }

            if (this.sortBy === 'price-high') {
                return (b.price || 0) - (a.price || 0);
            }

            if (this.sortBy === 'name') {
                return (a.productName || '').localeCompare(b.productName || '');
            }

            return a.order - b.order;
        });

        return result;
    }

    get collectionSections() {

        const filtered = this.filteredProducts;
        let visibleIndex = 0;

        return COLLECTIONS
            .map(collection => {

                const products = filtered
                    .filter(product => norm(product.collectionName) === collection.match)
                    .map(product => this.decorateProduct(product, visibleIndex++));

                return {
                    ...collection,
                    className: 'collection-block theme-' + collection.key,
                    products
                };
            })
            .filter(section => section.products.length > 0)
            .map((section, index) => ({
                ...section,
                hasDivider: index > 0
            }));
    }

    decorateProduct(product, position) {

        const id = product.productId;
        const isOutOfStock = product.stockStatus === 'OUT_OF_STOCK';
        const isLowStock = product.stockStatus === 'LOW_STOCK';
        const comparing = this.compareIds.includes(id);
        const raw = product.productImageUrl;

        let cartLabel = 'ADD TO CART';

        if (isOutOfStock) {
            cartLabel = 'REQUEST THIS PIECE';
        } else if (product.isAddingToCart) {
            cartLabel = 'ADDING…';
        }

        let heartClass = product.isWishlisted ? 'heart is-on' : 'heart';

        if (this.pulseId === id) {
            heartClass += ' is-pulse';
        }

        const specs = [
            product.movement,
            product.caseMaterial,
            product.waterResistance
        ].filter(value => value);

        return {
            ...product,
            hasImage: !!raw,
            imageSrc: cloudinary(raw, 'f_auto,q_auto,c_limit,w_900'),
            hiresSrc: cloudinary(raw, 'f_auto,q_auto,c_limit,w_2000'),
            imageSrcset: raw && raw.indexOf('res.cloudinary.com') !== -1
                ? cloudinary(raw, 'f_auto,q_auto,c_limit,w_560') + ' 560w, ' +
                  cloudinary(raw, 'f_auto,q_auto,c_limit,w_900') + ' 900w, ' +
                  cloudinary(raw, 'f_auto,q_auto,c_limit,w_1300') + ' 1300w'
                : undefined,
            placeholderStyle: raw
                ? 'background-image:url("' + cloudinary(raw, 'f_auto,q_10,w_48,e_blur:900') + '");'
                : '',
            imageLoading: position < 3 ? 'eager' : 'lazy',
            imageClass: this.loadedImages[id] ? 'watch-image-file is-loaded' : 'watch-image-file',
            line: tagline(product.description),
            formattedPrice: product.price ? '₹' + INR.format(product.price) : '',
            hasSpecs: specs.length > 0,
            specMovement: product.movement || '—',
            specCase: product.caseMaterial || '—',
            specWater: product.waterResistance || '—',
            specStrap: product.strapMaterial || '—',
            heartClass,
            wishlistTitle: product.isWishlisted ? 'Remove from Wishlist' : 'Add to Wishlist',
            wishlistPressed: product.isWishlisted ? 'true' : 'false',
            isOutOfStock,
            isLowStock,
            lowStockLabel: isLowStock ? 'ONLY ' + product.availableQuantity + ' REMAINING' : '',
            isLimited: product.limitedEdition === true,
            limitedLabel: product.editionSize ? 'LIMITED · ' + product.editionSize + ' PIECES' : 'LIMITED EDITION',
            stageClass: 'watch-stage' + (isOutOfStock ? ' is-archive' : ''),
            cartLabel,
            cartClass: isOutOfStock ? 'cart-button is-request' : 'cart-button',
            cartDisabled: product.isAddingToCart,
            compareClass: comparing ? 'mini-button is-on' : 'mini-button',
            compareLabel: comparing ? '✓ COMPARING' : '+ COMPARE',
            comparePressed: comparing ? 'true' : 'false'
        };
    }

    get visibleCount() {
        return String(this.filteredProducts.length).padStart(2, '0');
    }

    get totalCount() {
        return String(this.products.length).padStart(2, '0');
    }


    // =========================================================
    // THE CROWN DIAL
    // =========================================================

    get dialIndex() {
        return Math.max(0, DIAL.findIndex(entry => entry.value === this.activeCollection));
    }

    get crownStyle() {
        return 'transform: rotate(' + (-this.dialIndex * DIAL_STEP) + 'deg);';
    }

    get knobStyle() {
        return 'transform: rotate(' + (this.dialIndex * 90) + 'deg);';
    }

    get crownTicks() {

        const ticks = [];
        const perStep = 6;

        for (let k = -36; k <= 36; k++) {

            const angle = (k * DIAL_STEP) / perStep;
            const major = k >= 0 && k % perStep === 0 && k / perStep < DIAL.length;

            ticks.push({
                key: 't' + k,
                className: major ? 'tick is-major' : 'tick',
                style: 'transform: rotate(' + angle.toFixed(2) + 'deg) translateX(' + (major ? 128 : 132) + 'px);'
            });
        }

        return ticks;
    }

    get crownLabels() {

        return DIAL.map((entry, index) => {

            const active = index === this.dialIndex;

            return {
                ...entry,
                index: String(index),
                className: active ? 'dial-label is-active' : 'dial-label',
                style: 'transform: rotate(' + (index * DIAL_STEP) + 'deg) translateX(44px);',
                checked: active ? 'true' : 'false',
                tabIndex: active ? '0' : '-1'
            };
        });
    }

    get activeDialName() {
        return DIAL[this.dialIndex].label;
    }

    get collectionChips() {

        return DIAL.map(entry => ({
            ...entry,
            className: entry.value === this.activeCollection ? 'chip is-on' : 'chip'
        }));
    }

    setDial(index) {

        const next = Math.max(0, Math.min(DIAL.length - 1, index));

        if (next === this.dialIndex) {
            return;
        }

        this.activeCollection = DIAL[next].value;
    }

    handleDialClick(event) {
        if (this._crownDrag && this._crownDrag.moved) {
            return;
        }
        this.setDial(Number(event.currentTarget.dataset.index));
    }

    handleChip(event) {
        this.activeCollection = event.currentTarget.dataset.value;
    }

    handleKnob() {
        this.setDial((this.dialIndex + 1) % DIAL.length);
    }

    handleCrownWheel(event) {

        event.preventDefault();

        const now = Date.now();
        this._wheelAccumulator += event.deltaY;

        if (now - this._lastWheel < 220 || Math.abs(this._wheelAccumulator) < 30) {
            return;
        }

        this._lastWheel = now;
        this.setDial(this.dialIndex + (this._wheelAccumulator > 0 ? 1 : -1));
        this._wheelAccumulator = 0;
    }

    handleCrownKey(event) {

        if (event.key === 'ArrowDown' || event.key === 'ArrowRight') {
            event.preventDefault();
            this.setDial(this.dialIndex + 1);
        } else if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') {
            event.preventDefault();
            this.setDial(this.dialIndex - 1);
        }
    }

    handleCrownDown(event) {

        if (event.button !== undefined && event.button !== 0) {
            return;
        }

        this._crownDrag = { y: event.clientY, moved: false, start: this.dialIndex };

        window.addEventListener('pointermove', this.onCrownMove);
        window.addEventListener('pointerup', this.onCrownUp);
    }

    onCrownMove = event => {

        if (!this._crownDrag) {
            return;
        }

        const dy = event.clientY - this._crownDrag.y;

        if (Math.abs(dy) > 6) {
            this._crownDrag.moved = true;
        }

        this.setDial(this._crownDrag.start + Math.round(dy / 38));
    };

    onCrownUp = () => {

        window.removeEventListener('pointermove', this.onCrownMove);
        window.removeEventListener('pointerup', this.onCrownUp);

        // Keep "moved" for the click that follows, then clear.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._crownDrag = undefined; }, 0);
    };


    // =========================================================
    // REFINE DRAWER
    // =========================================================

    get facetGroups() {

        return FACETS.map(facet => {

            const counts = new Map();

            this.products.forEach(product => {
                const value = product[facet.key];
                if (value && this.passes(product, facet.key)) {
                    counts.set(value, (counts.get(value) || 0) + 1);
                }
            });

            // Keep chosen values visible even if their count is 0.
            (this.selected[facet.key] || []).forEach(value => {
                if (!counts.has(value)) {
                    counts.set(value, 0);
                }
            });

            const chosen = this.selected[facet.key] || [];

            return {
                ...facet,
                options: [...counts.entries()]
                    .sort((a, b) => a[0].localeCompare(b[0]))
                    .map(([value, count]) => ({
                        key: facet.key + '|' + value,
                        value,
                        count,
                        className: chosen.includes(value) ? 'facet is-on' : 'facet',
                        pressed: chosen.includes(value) ? 'true' : 'false'
                    }))
            };
        }).filter(group => group.options.length > 0);
    }

    handleFacet(event) {

        const { facet, value } = event.currentTarget.dataset;
        const current = this.selected[facet] || [];
        const next = current.includes(value)
            ? current.filter(entry => entry !== value)
            : [...current, value];

        this.selected = { ...this.selected, [facet]: next };
    }

    get sortOptions() {
        return SORTS.map(sort => ({
            ...sort,
            className: sort.value === this.sortBy ? 'segment is-on' : 'segment'
        }));
    }

    handleSort(event) {
        this.sortBy = event.currentTarget.dataset.value;
    }

    get limitedClass() {
        return this.limitedOnly ? 'switch is-on' : 'switch';
    }

    get stockClass() {
        return this.inStockOnly ? 'switch is-on' : 'switch';
    }

    get limitedPressed() {
        return this.limitedOnly ? 'true' : 'false';
    }

    get stockPressed() {
        return this.inStockOnly ? 'true' : 'false';
    }

    toggleLimited() {
        this.limitedOnly = !this.limitedOnly;
    }

    toggleInStock() {
        this.inStockOnly = !this.inStockOnly;
    }

    get moods() {

        return MOODS
            .filter(mood => this.products.some(product => mood.test(product)))
            .map(mood => ({
                ...mood,
                className: mood.key === this.activeMood ? 'mood is-on' : 'mood'
            }));
    }

    get hasMoods() {
        return this.moods.length > 0;
    }

    handleMood(event) {
        const key = event.currentTarget.dataset.key;
        this.activeMood = this.activeMood === key ? undefined : key;
    }

    get activeTokens() {

        const tokens = [];

        if (this.searchTerm) {
            tokens.push({ key: 'q', type: 'search', label: '“' + this.searchText.trim().toUpperCase() + '”' });
        }

        if (this.activeCollection !== 'ALL') {
            tokens.push({ key: 'c', type: 'collection', label: this.activeDialName });
        }

        if (this.activeMood) {
            const mood = MOODS.find(m => m.key === this.activeMood);
            tokens.push({ key: 'm', type: 'mood', label: mood ? mood.label : '' });
        }

        if (this.isPriceFiltered) {
            tokens.push({ key: 'p', type: 'price', label: this.priceLowLabel + ' – ' + this.priceHighLabel });
        }

        FACETS.forEach(facet => {
            (this.selected[facet.key] || []).forEach(value => {
                tokens.push({ key: facet.key + value, type: 'facet', facet: facet.key, value, label: value.toUpperCase() });
            });
        });

        if (this.limitedOnly) {
            tokens.push({ key: 'l', type: 'limited', label: 'LIMITED EDITIONS' });
        }

        if (this.inStockOnly) {
            tokens.push({ key: 's', type: 'stock', label: 'AVAILABLE NOW' });
        }

        return tokens;
    }

    get hasTokens() {
        return this.activeTokens.length > 0;
    }

    get refineCount() {
        return this.activeTokens.filter(token => token.type !== 'collection' && token.type !== 'search').length;
    }

    get hasRefineCount() {
        return this.refineCount > 0;
    }

    removeToken(event) {

        const { type, facet, value } = event.currentTarget.dataset;

        if (type === 'search') {
            this.clearSearch();
        } else if (type === 'collection') {
            this.activeCollection = 'ALL';
        } else if (type === 'mood') {
            this.activeMood = undefined;
        } else if (type === 'price') {
            this.resetPriceBounds();
        } else if (type === 'facet') {
            this.selected = {
                ...this.selected,
                [facet]: (this.selected[facet] || []).filter(entry => entry !== value)
            };
        } else if (type === 'limited') {
            this.limitedOnly = false;
        } else if (type === 'stock') {
            this.inStockOnly = false;
        }
    }

    resetFilters() {
        this.clearSearch();
        this.activeCollection = 'ALL';
        this.sortBy = 'featured';
        this.selected = {};
        this.limitedOnly = false;
        this.inStockOnly = false;
        this.activeMood = undefined;
        this.resetPriceBounds();
    }

    openRefine() {
        this.refineOpen = true;
    }

    closeRefine() {
        this.refineOpen = false;
    }

    get refineButtonLabel() {
        return 'SHOW ' + this.filteredProducts.length + ' TIMEPIECES';
    }


    // =========================================================
    // PAGE STATES
    // =========================================================

    get hasProducts() {
        return !this.isLoading && this.products.length > 0;
    }

    get showResults() {
        return this.hasProducts && this.filteredProducts.length > 0;
    }

    get showEmpty() {
        return this.hasProducts && this.filteredProducts.length === 0;
    }

    get hasError() {
        return !this.isLoading && this.error != null && this.products.length === 0;
    }

    get pageClass() {

        let className = 'watches-page';

        if (this.loupeOn) { className += ' is-loupe'; }
        if (this.dragId) { className += ' is-dragging'; }

        return className;
    }


    // =========================================================
    // IMAGES
    // =========================================================

    handleImageLoad(event) {
        const id = event.currentTarget.dataset.productId;
        if (id && !this.loadedImages[id]) {
            this.loadedImages = { ...this.loadedImages, [id]: true };
        }
    }


    // =========================================================
    // LOUPE
    // =========================================================

    get loupeClass() {
        return this.loupeOn ? 'instrument is-on' : 'instrument';
    }

    get loupePressed() {
        return this.loupeOn ? 'true' : 'false';
    }

    toggleLoupe() {
        this.loupeOn = !this.loupeOn;
        this.hideLoupe();
    }

    handleLoupeMove(event) {

        if (!this.loupeOn || event.pointerType === 'touch') {
            return;
        }

        const stage = event.currentTarget;
        const img = stage.querySelector('.watch-image-file');
        const lens = this.template.querySelector('.loupe');

        if (!img || !lens || !img.naturalWidth) {
            return;
        }

        const rect = stage.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;

        // Geometry of an object-fit: cover image.
        const scale = Math.max(rect.width / img.naturalWidth, rect.height / img.naturalHeight);
        const drawnW = img.naturalWidth * scale;
        const drawnH = img.naturalHeight * scale;
        const offsetX = (rect.width - drawnW) / 2;
        const offsetY = (rect.height - drawnH) / 2;

        const bgW = drawnW * LOUPE_ZOOM;
        const bgH = drawnH * LOUPE_ZOOM;
        const bgX = -((x - offsetX) * LOUPE_ZOOM - LOUPE_RADIUS);
        const bgY = -((y - offsetY) * LOUPE_ZOOM - LOUPE_RADIUS);

        const sharp = stage.dataset.hires || img.currentSrc || img.src;

        lens.style.opacity = '1';
        lens.style.transform = 'translate3d(' + (event.clientX - LOUPE_RADIUS) + 'px,' + (event.clientY - LOUPE_RADIUS) + 'px,0)';
        lens.style.backgroundImage = 'url("' + sharp + '")';
        lens.style.backgroundSize = bgW.toFixed(0) + 'px ' + bgH.toFixed(0) + 'px';
        lens.style.backgroundPosition = bgX.toFixed(1) + 'px ' + bgY.toFixed(1) + 'px';
    }

    hideLoupe() {

        const lens = this.template.querySelector('.loupe');

        if (lens) {
            lens.style.opacity = '0';
        }
    }

    // =========================================================
    // COMPARE TRAY (drag or button)
    // =========================================================

    get showDock() {
        return this.hasProducts && (this.compareIds.length > 0 || !!this.dragId);
    }

    get dockClass() {

        let className = 'dock';

        if (this.dragId) { className += ' is-awake'; }
        if (this.overDock) { className += ' is-over'; }

        return className;
    }

    get dockSlots() {

        const slots = [];

        for (let i = 0; i < MAX_COMPARE; i++) {

            const product = this.products.find(p => p.productId === this.compareIds[i]);

            slots.push({
                key: 'slot' + i,
                filled: !!product,
                image: product ? cloudinary(product.productImageUrl, 'f_auto,q_auto,w_160,h_160,c_fill') : null,
                name: product ? product.productName : '',
                productId: product ? product.productId : '',
                className: product ? 'slot is-filled' : 'slot'
            });
        }

        return slots;
    }

    get dockLabel() {

        if (this.dragId) {
            return 'RELEASE TO COMPARE';
        }

        if (this.compareIds.length >= 2) {
            return 'COMPARE ' + this.compareIds.length;
        }

        return 'ADD ONE MORE';
    }

    get dockDisabled() {
        return this.compareIds.length < 2;
    }

    addToCompare(id) {

        if (this.compareIds.includes(id)) {
            return;
        }

        if (this.compareIds.length >= MAX_COMPARE) {
            this.compareIds = [...this.compareIds.slice(1), id];
        } else {
            this.compareIds = [...this.compareIds, id];
        }
    }

    toggleCompare(event) {

        event.stopPropagation();

        const id = event.currentTarget.dataset.productId;

        if (this.compareIds.includes(id)) {
            this.compareIds = this.compareIds.filter(value => value !== id);
            return;
        }

        this.addToCompare(id);
    }

    removeFromDock(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.productId;
        this.compareIds = this.compareIds.filter(value => value !== id);
    }

    openCompare() {
        if (this.compareIds.length >= 2) {
            this.compareOpen = true;
        }
    }

    closeCompare() {
        this.compareOpen = false;
    }

    clearCompare() {
        this.compareOpen = false;
        this.compareIds = [];
    }

    get showCompare() {
        return this.compareOpen && this.compareIds.length >= 2;
    }

    get comparePieces() {

        const pieces = this.compareIds
            .map(id => this.products.find(p => p.productId === id))
            .filter(p => p);

        const max = Math.max(1, ...pieces.map(p => p.price || 0));

        return pieces.map(piece => ({
            productId: piece.productId,
            productName: piece.productName,
            collectionName: piece.collectionName,
            image: cloudinary(piece.productImageUrl, 'f_auto,q_auto,c_limit,w_700'),
            formattedPrice: piece.price ? '₹' + INR.format(piece.price) : 'Price on request',
            barStyle: 'width:' + Math.round(((piece.price || 0) / max) * 100) + '%;'
        }));
    }

    get compareRows() {

        const pieces = this.compareIds
            .map(id => this.products.find(p => p.productId === id))
            .filter(p => p)
            .map(p => ({
                ...p,
                editionLabel: p.limitedEdition
                    ? (p.editionSize ? 'Limited · ' + p.editionSize + ' pieces' : 'Limited edition')
                    : 'Regular production',
                warrantyLabel: p.warrantyMonths ? p.warrantyMonths + ' months' : null
            }));

        return COMPARE_ROWS
            .filter(([, field]) => pieces.some(p => p[field]))
            .map(([label, field]) => {

                const values = pieces.map(p => p[field] || '—');
                const same = values.every(v => v !== '—' && norm(v) === norm(values[0]));

                return {
                    key: field,
                    label,
                    className: same ? 'compare-row is-same' : 'compare-row',
                    cells: values.map((value, index) => ({ key: field + index, value }))
                };
            });
    }

    get compareGridStyle() {
        return '--cols:' + this.compareIds.length + ';';
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    // Drag starts on the watch image (mouse) or the ⠿ grip (touch).
    handleStageDown(event) {

        if (this.loupeOn || event.pointerType !== 'mouse' || event.button !== 0) {
            return;
        }

        this._pending = {
            id: event.currentTarget.dataset.productId,
            x: event.clientX,
            y: event.clientY
        };

        window.addEventListener('pointermove', this.onPendingMove);
        window.addEventListener('pointerup', this.onPendingUp);
    }

    onPendingMove = event => {

        if (!this._pending) {
            return;
        }

        if (Math.hypot(event.clientX - this._pending.x, event.clientY - this._pending.y) > DRAG_THRESHOLD) {
            const id = this._pending.id;
            this.clearPending();
            this.beginDrag(id, event.clientX, event.clientY);
        }
    };

    onPendingUp = () => {
        this.clearPending();
    };

    clearPending() {
        this._pending = undefined;
        window.removeEventListener('pointermove', this.onPendingMove);
        window.removeEventListener('pointerup', this.onPendingUp);
    }

    handleGripDown(event) {
        event.preventDefault();
        event.stopPropagation();
        this.beginDrag(event.currentTarget.dataset.productId, event.clientX, event.clientY);
    }

    stopClick(event) {
        event.stopPropagation();
    }

    beginDrag(id, x, y) {

        const product = this.products.find(p => p.productId === id);

        if (!product) {
            return;
        }

        this.dragId = id;
        this.dragImage = cloudinary(product.productImageUrl, 'f_auto,q_auto,w_360');
        this.overDock = false;

        window.addEventListener('pointermove', this.onDragMove);
        window.addEventListener('pointerup', this.onDragEnd);
        window.addEventListener('pointercancel', this.onDragEnd);

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => this.moveGhost(x, y));
    }

    onDragMove = event => {

        if (!this.dragId) {
            return;
        }

        event.preventDefault();

        const x = event.clientX;
        const y = event.clientY;
        const dock = this.template.querySelector('.dock');

        let over = false;

        if (dock) {
            const r = dock.getBoundingClientRect();
            over = x > r.left - 30 && x < r.right + 30 && y > r.top - 50 && y < r.bottom + 30;
        }

        if (over !== this.overDock) {
            this.overDock = over;
        }

        this.moveGhost(x, y);

        if (y < 80) {
            window.scrollBy(0, -14);
        } else if (y > window.innerHeight - 140 && !over) {
            window.scrollBy(0, 14);
        }
    };

    onDragEnd = () => {

        const dragged = this.dragId;
        const over = this.overDock;

        this.stopDragListeners();

        this.dragId = undefined;
        this.overDock = false;

        this._justDragged = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._justDragged = false; }, 80);

        if (dragged && over) {
            this.addToCompare(dragged);
        }
    };

    stopDragListeners() {
        window.removeEventListener('pointermove', this.onDragMove);
        window.removeEventListener('pointerup', this.onDragEnd);
        window.removeEventListener('pointercancel', this.onDragEnd);
        window.removeEventListener('pointermove', this.onCrownMove);
        window.removeEventListener('pointerup', this.onCrownUp);
    }

    moveGhost(x, y) {

        const ghost = this.template.querySelector('.ghost');

        if (ghost) {
            ghost.style.transform =
                'translate3d(' + x.toFixed(1) + 'px,' + y.toFixed(1) + 'px,0) translate(-50%,-50%) rotate(-6deg)' +
                (this.overDock ? ' scale(0.7)' : '');
        }
    }


    // =========================================================
    // CART
    // =========================================================

    async handleAddToCart(event) {

        event.stopPropagation();

        const productId = event.currentTarget.dataset.productId;
        const product = this.products.find(p => p.productId === productId);

        if (!product) {
            return;
        }

        // Archive piece: request it from the product page.
        if (product.stockStatus === 'OUT_OF_STOCK') {
            this.navigateToProduct(productId);
            return;
        }

        if (isGuestUser) {
            this.showGuestCartModal = true;
            return;
        }

        this.updateProduct(productId, { isAddingToCart: true });

        try {

            await addToCart({ productId, quantity: 1 });

            window.dispatchEvent(new CustomEvent('ujjayini:cartchange'));

            this.showNotificationPopup(
                'success',
                'ADDED TO CART',
                'The timepiece is waiting in your cart.'
            );

        } catch (error) {

            this.showNotificationPopup('error', 'UNABLE TO ADD', this.getErrorMessage(error));

        } finally {

            this.updateProduct(productId, { isAddingToCart: false });
        }
    }


    // =========================================================
    // WISHLIST
    // =========================================================

    async handleWishlist(event) {

        event.stopPropagation();

        if (isGuestUser) {
            this.showGuestCartModal = true;
            return;
        }

        const productId = event.currentTarget.dataset.productId;
        const product = this.products.find(p => p.productId === productId);

        if (!product || product.isAddingToWishlist) {
            return;
        }

        const adding = !product.isWishlisted;

        // Optimistic: the heart reacts instantly.
        this.updateProduct(productId, { isWishlisted: adding, isAddingToWishlist: true });

        if (adding) {
            this.pulse(productId);
        }

        try {

            if (adding) {
                await addToWishlist({ productId });
            } else {
                await removeFromWishlist({ productId });
            }

            this.showNotificationPopup(
                'success',
                adding ? 'SAVED TO WISHLIST' : 'REMOVED FROM WISHLIST',
                adding
                    ? 'The timepiece will wait for you in your wishlist.'
                    : 'The timepiece has left your wishlist.'
            );

        } catch (error) {

            this.updateProduct(productId, { isWishlisted: !adding });
            this.showNotificationPopup('error', 'WISHLIST UNAVAILABLE', this.getErrorMessage(error));

        } finally {

            this.updateProduct(productId, { isAddingToWishlist: false });
        }
    }

    pulse(id) {

        clearTimeout(this._pulseTimer);
        this.pulseId = id;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._pulseTimer = setTimeout(() => {
            this.pulseId = undefined;
        }, 750);
    }

    updateProduct(productId, changes) {
        this.products = this.products.map(product =>
            product.productId === productId ? { ...product, ...changes } : product
        );
    }


    // =========================================================
    // NAVIGATION
    // =========================================================

    handleProductClick(event) {

        event.stopPropagation();

        if (this._justDragged) {
            return;
        }

        this.navigateToProduct(event.currentTarget.dataset.productId);
    }

    navigateToProduct(productId) {

        if (!productId) {
            return;
        }

        this.compareOpen = false;

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Product_Detail__c' },
            state: { productId }
        });
    }

    handleScrollToCatalog() {

        const target = this.template.querySelector('.catalog-workspace');

        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }


    // =========================================================
    // NOTIFICATION
    // =========================================================

    showNotificationPopup(type, title, message) {

        clearTimeout(this._notificationTimer);

        this.notificationType = type;
        this.notificationTitle = title;
        this.notificationMessage = message;
        this.showNotification = true;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._notificationTimer = setTimeout(() => {
            this.showNotification = false;
        }, 4000);
    }

    closeNotification() {
        this.showNotification = false;
        clearTimeout(this._notificationTimer);
    }

    get notificationClass() {
        return this.notificationType === 'error'
            ? 'ujjayini-notification is-error'
            : 'ujjayini-notification';
    }

    get notificationSymbol() {
        return this.notificationType === 'error' ? '!' : '✓';
    }


    // =========================================================
    // GUEST MODAL
    // =========================================================

    closeGuestCartModal() {
        this.showGuestCartModal = false;
    }

    stopModalPropagation(event) {
        event.stopPropagation();
    }

    handleGuestLogin() {
        const startUrl = window.location.pathname + window.location.search;
        window.location.href = '/ujjayini/login?startURL=' + encodeURIComponent(startUrl);
    }

    handleGuestSignup() {
        window.location.href = '/ujjayini/SelfRegister';
    }


    // =========================================================
    // ERRORS (never technical)
    // =========================================================

    get errorMessage() {
        return 'The vault is taking a moment to open. Please refresh the page.';
    }

    getErrorMessage(error) {

        const raw = (error && error.body && error.body.message) || (error && error.message) || '';

        if (!raw || /apex|exception|System\.|script-thrown|cacheable|invalid|null/i.test(raw)) {
            return FRIENDLY_ERROR;
        }

        return raw;
    }
}