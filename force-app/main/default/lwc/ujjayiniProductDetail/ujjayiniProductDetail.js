import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import isGuestUser from '@salesforce/user/isGuest';

import getProduct
    from '@salesforce/apex/UJJAYINIProductCatalogController.getProduct';

import getProducts
    from '@salesforce/apex/UJJAYINIProductCatalogController.getProducts';

import addToCart
    from '@salesforce/apex/UJJAYINICartController.addToCart';

import getCurrentCart
    from '@salesforce/apex/UJJAYINICartController.getCurrentCart';

import productVideo
    from '@salesforce/resourceUrl/UJJAYINI_Product_Detail_Video';


// =========================================================
// CONFIG
// =========================================================

const CHAPTERS = 5;

// Where the "camera" sits in each chapter.
// frameX: frame position (vw), scale/x/y/rotate: image inside the frame.
const CAMERA = [
    { frameX: 16, frameScale: 1, scale: 1, x: 0, y: 0, rotate: 0 },
    { frameX: 0, frameScale: 1.08, scale: 2.05, x: 0, y: 0, rotate: 0 },
    { frameX: -17, frameScale: 1, scale: 1.55, x: -9, y: 2, rotate: -5 },
    { frameX: 17, frameScale: 1, scale: 1.35, x: 10, y: -2, rotate: 4 },
    { frameX: 0, frameScale: 0.82, scale: 1.04, x: 0, y: 0, rotate: 0 }
];

const SKIN_TONES = [
    { key: 'porcelain', label: 'Porcelain', color: '#f1d3bd' },
    { key: 'sand', label: 'Sand', color: '#dcb08a' },
    { key: 'honey', label: 'Honey', color: '#b9825a' },
    { key: 'umber', label: 'Umber', color: '#8a5a3c' },
    { key: 'ebony', label: 'Ebony', color: '#56372a' }
];

const CASE_SIZES = [38, 40, 42, 44];

const INR = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
});

const FRIENDLY_ERROR = 'Something interrupted the moment. Please try again.';

const LOUPE_ZOOM = 2.5;
const LOUPE_RADIUS = 95;

// Points the Macro Inspect tour visits (as % of the image).
const INSPECT_POINTS = [
    { x: 50, y: 48, label: 'THE DIAL' },
    { x: 66, y: 30, label: 'THE BEZEL' },
    { x: 36, y: 64, label: 'THE CASE EDGE' }
];

function cloudinary(url, transform) {

    if (!url || url.indexOf('res.cloudinary.com') === -1 || url.indexOf('/upload/') === -1) {
        return url;
    }

    return url.replace('/upload/', '/upload/' + transform + '/');
}

function norm(value) {
    return (value || '')
        .toString()
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .toLowerCase()
        .trim();
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}

function ease(t) {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}


export default class UjjayiniProductDetail extends LightningElement {

    // =========================================================
    // STATE
    // =========================================================

    productId;
    product;
    isLoading = true;
    errorMessage;

    isAddingToCart = false;
    isBuyingNow = false;

    chapter = 0;
    isCompact = false;
    showBuyBar = false;

    // Wrist fit
    wristMm = 165;
    caseMm = 42;
    skinKey = 'sand';

    // Loupe
    loupeActive = false;
    isTouring = false;
    tourLabel = '';

    // Similar
    similar = [];

    // Notification
    showNotification = false;
    notificationType = '';
    notificationTitle = '';
    notificationMessage = '';

    // Guest
    showGuestCartModal = false;

    videoUrl = productVideo;

    _videoInitialized = false;
    _notificationTimer;
    _frame;
    _stickyBroken = false;
    _tourTimers = [];


    // =========================================================
    // PAGE REFERENCE
    // =========================================================

    @wire(CurrentPageReference)
    getPageReference(pageReference) {

        if (pageReference && pageReference.state) {

            const productId = pageReference.state.productId || pageReference.state.c__productId;

            if (productId && productId !== this.productId) {
                this.productId = productId;
                this.loadProduct();
            }
        }
    }


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        this.updateCompact();

        window.addEventListener('scroll', this.handleScroll, { passive: true });
        window.addEventListener('resize', this.handleResize, { passive: true });

        // Give up waiting for a product id that never comes.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            if (!this.productId && this.isLoading) {
                this.isLoading = false;
                this.errorMessage = 'This timepiece could not be found.';
            }
        }, 4000);
    }

    disconnectedCallback() {

        window.removeEventListener('scroll', this.handleScroll);
        window.removeEventListener('resize', this.handleResize);

        clearTimeout(this._notificationTimer);
        this.stopTour();

        if (this._frame) {
            cancelAnimationFrame(this._frame);
        }
    }

    renderedCallback() {
        this.initVideo();
        this.handleScroll();
    }

    initVideo() {

        if (this._videoInitialized) {
            return;
        }

        const video = this.template.querySelector('.product-video');

        if (!video) {
            return;
        }

        this._videoInitialized = true;
        video.muted = true;
        video.defaultMuted = true;
        video.playsInline = true;

        if (this.reduceMotion) {
            video.pause();
            return;
        }

        const playing = video.play();

        if (playing && playing.catch) {
            playing.catch(() => {
                // Autoplay blocked: the page still works.
            });
        }
    }

    get reduceMotion() {
        return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    }

    handleResize = () => {
        this.updateCompact();
        this.handleScroll();
    };

    updateCompact() {
        const compact = window.innerWidth <= 860 || this.reduceMotion;
        if (compact !== this.isCompact) {
            this.isCompact = compact;
        }
    }


    // =========================================================
    // LOAD
    // =========================================================

    async loadProduct() {

        this.isLoading = true;
        this.errorMessage = undefined;
        this.chapter = 0;

        try {

            this.product = await getProduct({ productId: this.productId });
            this.loadSimilar();

        } catch (error) {

            this.product = undefined;
            this.errorMessage = 'This timepiece is resting in the vault. Please return to the collection.';

        } finally {

            this.isLoading = false;
        }
    }

    async loadSimilar() {

        try {

            const all = (await getProducts()) || [];
            const current = this.product;
            const others = all.filter(p => p.productId !== current.productId);
            const sameCollection = others.filter(p => norm(p.collectionName) === norm(current.collectionName));
            const rest = others
                .filter(p => norm(p.collectionName) !== norm(current.collectionName))
                .sort((a, b) => Math.abs((a.price || 0) - (current.price || 0)) - Math.abs((b.price || 0) - (current.price || 0)));

            this.similar = [...sameCollection, ...rest].slice(0, 3).map((p, index) => ({
                productId: p.productId,
                productName: p.productName,
                collectionName: p.collectionName,
                image: cloudinary(p.productImageUrl, 'f_auto,q_auto,c_limit,w_700'),
                hasImage: !!p.productImageUrl,
                price: p.price ? INR.format(p.price) : 'Price on request',
                index: String(index + 1).padStart(2, '0'),
                isArchive: p.stockStatus === 'OUT_OF_STOCK',
                className: 'similar-card theme-' + this.themeKey(p.collectionName)
            }));

        } catch (e) {
            this.similar = [];
        }
    }


    // =========================================================
    // VIEW DATA
    // =========================================================

    get hasProduct() {
        return !this.isLoading && !!this.product;
    }

    get showError() {
        return !this.isLoading && !!this.errorMessage;
    }

    themeKey(collection) {
        const key = norm(collection);
        if (key === 'indranila' || key === 'hiranya' || key === 'ayas') {
            return key;
        }
        return 'house';
    }

    get pageClass() {
        let className = 'product-page theme-' + this.themeKey(this.product && this.product.collectionName);
        if (this.isCompact) {
            className += ' is-compact';
        }
        return className;
    }

    get imageSrc() {
        return cloudinary(this.product && this.product.productImageUrl, 'f_auto,q_auto,c_limit,w_1600');
    }

    get imageHires() {
        return cloudinary(this.product && this.product.productImageUrl, 'f_auto,q_auto,c_limit,w_2600');
    }

    get hasImage() {
        return !!(this.product && this.product.productImageUrl);
    }

    get formattedPrice() {
        return this.product && this.product.price !== null && this.product.price !== undefined
            ? INR.format(this.product.price)
            : 'Price on request';
    }

    get description() {
        return (this.product && this.product.description) ||
            'A UJJAYINI timepiece created for those who understand the quiet language of precision.';
    }

    get isOutOfStock() {
        return !!this.product && this.product.stockStatus === 'OUT_OF_STOCK';
    }

    get isLowStock() {
        return !!this.product && this.product.stockStatus === 'LOW_STOCK';
    }

    get stockLabel() {

        if (this.isOutOfStock) {
            return 'ARCHIVE PIECE · REQUEST A PRIVATE VIEWING';
        }

        if (this.isLowStock) {
            return 'ONLY ' + this.product.availableQuantity + ' REMAINING';
        }

        return 'AVAILABLE · SHIPS INSURED';
    }

    get stockClass() {
        if (this.isOutOfStock) {
            return 'stock is-archive';
        }
        return this.isLowStock ? 'stock is-low' : 'stock';
    }

    get disableActions() {
        return this.isAddingToCart || this.isBuyingNow;
    }

    get buyNowLabel() {
        if (this.isOutOfStock) {
            return 'REQUEST THIS PIECE';
        }
        return this.isBuyingNow ? 'PREPARING…' : 'BUY NOW';
    }

    get cartLabel() {
        return this.isAddingToCart ? 'ADDING…' : 'ADD TO CART';
    }

    get showCartButton() {
        return !this.isOutOfStock;
    }


    // ---------- Chapters ----------

    spec(label, value) {
        return value ? { key: label, label, value } : null;
    }

    get chapterData() {

        const p = this.product || {};
        const edition = p.limitedEdition
            ? (p.editionSize ? 'Limited · ' + p.editionSize + ' pieces' : 'Limited edition')
            : 'Regular production';

        return [
            null,
            {
                number: '01',
                kicker: 'THE DIAL',
                title: 'A face that',
                accent: 'keeps its own light.',
                copy: 'Look closer. Every marker, every line on the dial was placed by hand, to be read in a glance and remembered for years.',
                specs: [this.spec('DIAL', p.dialColor), this.spec('MODEL', p.modelNumber)]
            },
            {
                number: '02',
                kicker: 'THE HEART',
                title: 'Every second,',
                accent: 'earned.',
                copy: 'Beneath the dial, a living mechanism. Gears that turn in quiet agreement, measuring a life one beat at a time.',
                specs: [this.spec('MOVEMENT', p.movement), this.spec('WATER RESISTANCE', p.waterResistance)]
            },
            {
                number: '03',
                kicker: 'THE CASE',
                title: 'Metal, made',
                accent: 'to outlive us.',
                copy: 'The case is shaped, polished and finished to hold the heart safely, and to catch the light the way only real metal can.',
                specs: [this.spec('CASE', p.caseMaterial), this.spec('STRAP', p.strapMaterial), this.spec('MAISON', p.brand)]
            },
            {
                number: '04',
                kicker: 'THE RARITY',
                title: p.limitedEdition ? 'Made for' : 'Made for those',
                accent: p.limitedEdition ? 'very few.' : 'who notice.',
                copy: p.limitedEdition
                    ? 'A numbered edition. When the last piece finds its owner, the edition closes forever.'
                    : 'Crafted in measured numbers, finished with the same patience as our rarest pieces.',
                specs: [
                    this.spec('EDITION', edition),
                    this.spec('WARRANTY', p.warrantyMonths ? p.warrantyMonths + ' months' : null),
                    this.spec('REFERENCE', p.productCode)
                ]
            }
        ];
    }

    get chapters() {

        return this.chapterData
            .map((data, index) => {

                if (!data) {
                    return null;
                }

                const active = index === this.chapter;
                const side = index === 2 ? 'right' : 'left';

                return {
                    ...data,
                    key: 'ch' + index,
                    specs: data.specs.filter(s => s),
                    className: 'chapter chapter-' + index + ' is-' + side + (active ? ' is-active' : '')
                };
            })
            .filter(c => c);
    }

    get prologueClass() {
        return this.chapter === 0 ? 'prologue is-active' : 'prologue';
    }

    get stageClass() {
        return 'stage at-' + this.chapter;
    }

    get rarityNumber() {
        const p = this.product || {};
        if (p.limitedEdition && p.editionSize) {
            return String(p.editionSize).padStart(2, '0');
        }
        return p.limitedEdition ? '01' : '∞';
    }

    get rarityLabel() {
        const p = this.product || {};
        return p.limitedEdition ? 'PIECES IN THE WORLD' : 'ONE AT A TIME';
    }

    get chapterDots() {

        const names = ['PROLOGUE', 'DIAL', 'HEART', 'CASE', 'RARITY'];

        return names.map((name, index) => ({
            key: 'dot' + index,
            index: String(index),
            name,
            number: String(index).padStart(2, '0'),
            className: index === this.chapter ? 'dot is-active' : (index < this.chapter ? 'dot is-done' : 'dot')
        }));
    }

    get chapterCounter() {
        return String(this.chapter).padStart(2, '0') + ' / 04';
    }

    get buyBarClass() {
        return this.showBuyBar ? 'buy-bar is-visible' : 'buy-bar';
    }


    // =========================================================
    // SCROLL CAMERA
    // =========================================================

    handleScroll = () => {

        if (this._frame) {
            return;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._frame = requestAnimationFrame(() => {
            this._frame = undefined;
            this.updateCamera();
        });
    };

    updateCamera() {

        const story = this.template.querySelector('.story');
        const stage = this.template.querySelector('.stage');

        if (!story || !stage) {
            return;
        }

        const viewport = window.innerHeight || 800;
        const rect = story.getBoundingClientRect();

        // Buy bar: after the prologue, until the page ends.
        const pastPrologue = rect.top < -viewport * 0.6;
        if (pastPrologue !== this.showBuyBar) {
            this.showBuyBar = pastPrologue;
        }

        if (this.isCompact) {
            stage.style.transform = '';
            return;
        }

        const travel = Math.max(1, rect.height - viewport);
        const progress = Math.min(1, Math.max(0, -rect.top / travel));

        // Fallback when the site container breaks position: sticky.
        const stageTop = stage.getBoundingClientRect().top;
        if (!this._stickyBroken && rect.top < -4 && -rect.top < travel - 4 && Math.abs(stageTop) > 6) {
            this._stickyBroken = true;
        }

        if (this._stickyBroken) {
            const offset = Math.min(travel, Math.max(0, -rect.top));
            stage.style.transform = 'translate3d(0,' + offset.toFixed(1) + 'px,0)';
        }

        // Chapter + camera.
        const position = progress * (CHAPTERS - 1);
        const index = Math.min(CHAPTERS - 1, Math.round(position));

        if (index !== this.chapter) {
            this.chapter = index;
        }

        const from = Math.floor(position);
        const to = Math.min(CHAPTERS - 1, from + 1);
        const t = ease(position - from);
        const a = CAMERA[from];
        const b = CAMERA[to];

        const frame = this.template.querySelector('.frame');
        const lens = this.template.querySelector('.frame-image');
        const hand = this.template.querySelector('.chrono-hand');

        if (frame) {
            frame.style.transform =
                'translate3d(' + lerp(a.frameX, b.frameX, t).toFixed(2) + 'vw,0,0) ' +
                'scale(' + lerp(a.frameScale, b.frameScale, t).toFixed(3) + ')';
        }

        if (lens) {
            lens.style.transform =
                'translate3d(' + lerp(a.x, b.x, t).toFixed(2) + '%,' + lerp(a.y, b.y, t).toFixed(2) + '%,0) ' +
                'scale(' + lerp(a.scale, b.scale, t).toFixed(3) + ') ' +
                'rotate(' + lerp(a.rotate, b.rotate, t).toFixed(2) + 'deg)';
        }

        if (hand) {
            hand.style.transform = 'rotate(' + (progress * 360).toFixed(1) + 'deg)';
        }

        stage.style.setProperty('--progress', progress.toFixed(4));
    }

    jumpToChapter(event) {

        const index = Number(event.currentTarget.dataset.index);
        const story = this.template.querySelector('.story');

        if (!story || this.isCompact) {
            return;
        }

        const viewport = window.innerHeight || 800;
        const travel = story.offsetHeight - viewport;
        const top = story.getBoundingClientRect().top + window.scrollY;

        window.scrollTo({
            top: top + (travel * index) / (CHAPTERS - 1) + 2,
            behavior: 'smooth'
        });
    }

    scrollToSection(selector) {
        const target = this.template.querySelector(selector);
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    goToInspect() {
        this.scrollToSection('.inspect');
    }

    goToFit() {
        this.scrollToSection('.fit');
    }


    // =========================================================
    // MACRO INSPECT (Jeweller's loupe)
    // =========================================================

    get inspectClass() {
        let className = 'inspect-stage';
        if (this.loupeActive) { className += ' is-loupe'; }
        if (this.isTouring) { className += ' is-touring'; }
        return className;
    }

    get tourButtonLabel() {
        return this.isTouring ? 'STOP TOUR' : 'MACRO TOUR';
    }

    handleInspectEnter() {
        this.loupeActive = true;
    }

    handleInspectLeave() {
        if (!this.isTouring) {
            this.loupeActive = false;
            this.hideLens();
        }
    }

    handleInspectMove(event) {

        if (this.isTouring || event.pointerType === 'touch') {
            return;
        }

        const stage = event.currentTarget;
        const rect = stage.getBoundingClientRect();

        this.placeLens(event.clientX - rect.left, event.clientY - rect.top);
    }

    placeLens(x, y) {

        const stage = this.template.querySelector('.inspect-stage');
        const img = this.template.querySelector('.inspect-image');
        const lens = this.template.querySelector('.lens');

        if (!stage || !img || !lens || !img.naturalWidth) {
            return;
        }

        const rect = stage.getBoundingClientRect();

        // object-fit: contain geometry
        const scale = Math.min(rect.width / img.naturalWidth, rect.height / img.naturalHeight);
        const drawnW = img.naturalWidth * scale;
        const drawnH = img.naturalHeight * scale;
        const offsetX = (rect.width - drawnW) / 2;
        const offsetY = (rect.height - drawnH) / 2;

        lens.style.opacity = '1';
        lens.style.transform = 'translate3d(' + (x - LOUPE_RADIUS) + 'px,' + (y - LOUPE_RADIUS) + 'px,0)';
        lens.style.backgroundImage = 'url("' + this.imageHires + '")';
        lens.style.backgroundSize = (drawnW * LOUPE_ZOOM).toFixed(0) + 'px ' + (drawnH * LOUPE_ZOOM).toFixed(0) + 'px';
        lens.style.backgroundPosition =
            (-((x - offsetX) * LOUPE_ZOOM - LOUPE_RADIUS)).toFixed(1) + 'px ' +
            (-((y - offsetY) * LOUPE_ZOOM - LOUPE_RADIUS)).toFixed(1) + 'px';
    }

    hideLens() {
        const lens = this.template.querySelector('.lens');
        if (lens) {
            lens.style.opacity = '0';
        }
    }

    toggleTour() {

        if (this.isTouring) {
            this.stopTour();
            this.loupeActive = false;
            this.hideLens();
            return;
        }

        const stage = this.template.querySelector('.inspect-stage');
        const img = this.template.querySelector('.inspect-image');

        if (!stage || !img || !img.naturalWidth) {
            return;
        }

        this.isTouring = true;
        this.loupeActive = true;

        const rect = stage.getBoundingClientRect();
        const scale = Math.min(rect.width / img.naturalWidth, rect.height / img.naturalHeight);
        const drawnW = img.naturalWidth * scale;
        const drawnH = img.naturalHeight * scale;
        const offsetX = (rect.width - drawnW) / 2;
        const offsetY = (rect.height - drawnH) / 2;

        INSPECT_POINTS.forEach((point, index) => {

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._tourTimers.push(setTimeout(() => {
                this.tourLabel = point.label;
                this.placeLens(offsetX + (drawnW * point.x) / 100, offsetY + (drawnH * point.y) / 100);
            }, index * 2200));
        });

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._tourTimers.push(setTimeout(() => {
            this.stopTour();
            this.loupeActive = false;
            this.hideLens();
        }, INSPECT_POINTS.length * 2200 + 400));
    }

    stopTour() {
        this._tourTimers.forEach(timer => clearTimeout(timer));
        this._tourTimers = [];
        this.isTouring = false;
        this.tourLabel = '';
    }


    // =========================================================
    // WRIST FIT VISUALIZER
    // =========================================================

    get wristLabel() {
        return this.wristMm + ' mm';
    }

    get caseLabel() {
        return this.caseMm + ' mm';
    }

    // Top-view width of the wrist, roughly 36% of its circumference.
    get wristWidthMm() {
        return this.wristMm * 0.36;
    }

    get fitRatio() {
        return this.caseMm / this.wristWidthMm;
    }

    get fitVerdict() {
        const r = this.fitRatio;
        if (r < 0.66) { return 'DISCREET'; }
        if (r <= 0.8) { return 'BALANCED'; }
        return 'A BOLD STATEMENT';
    }

    get fitCopy() {
        const r = this.fitRatio;
        if (r < 0.66) {
            return 'Slips under a cuff. Quiet elegance that reveals itself only when you choose.';
        }
        if (r <= 0.8) {
            return 'Lug to lug, the case sits within your wrist: the proportion watchmakers aim for.';
        }
        return 'The case commands the wrist. Made to be noticed from across the room.';
    }

    get fitMeterStyle() {
        const pct = Math.min(100, Math.max(0, ((this.fitRatio - 0.5) / 0.45) * 100));
        return 'left:' + pct.toFixed(1) + '%;';
    }

    get skinColor() {
        const tone = SKIN_TONES.find(t => t.key === this.skinKey) || SKIN_TONES[1];
        return tone.color;
    }

    // ---------- The wrist drawing ----------
    // A top-down forearm, wrist and relaxed fist, drawn in a fixed
    // 900 x 460 canvas. 1 mm = 3.6 units, so the watch and the wrist
    // keep their true proportion.

    get wristHalf() {
        return (this.wristWidthMm * 3.6) / 2;
    }

    get armPath() {

        const h = this.wristHalf;
        const c = 400;
        const y = 230;
        const k = 1.18;
        const f = n => n.toFixed(1);
        const X = n => f(c + n * h);
        const Y = n => f(y + n * h);

        return [
            'M 0 ' + Y(-1.32),
            'C 150 ' + Y(-1.3) + ' 300 ' + Y(-1.1) + ' ' + f(c) + ' ' + Y(-1),
            'C ' + X(0.45) + ' ' + Y(-0.97) + ' ' + X(0.72) + ' ' + Y(-1.12) + ' ' + X(1.02) + ' ' + Y(-1.26),
            'C ' + X(1.45) + ' ' + Y(-1.46) + ' ' + X(2.05) + ' ' + Y(-1.5) + ' ' + X(2.38) + ' ' + Y(-1.34),
            'C ' + X(2.58) + ' ' + Y(-1.24) + ' ' + X(2.72) + ' ' + Y(-1.2 * k + 0.2) + ' ' + X(2.86) + ' ' + Y(-1.0 * k),
            'Q ' + X(3.1) + ' ' + Y(-0.88 * k) + ' ' + X(3.02) + ' ' + Y(-0.58 * k),
            'Q ' + X(3.17) + ' ' + Y(-0.3 * k) + ' ' + X(3.05) + ' ' + Y(-0.02 * k),
            'Q ' + X(3.16) + ' ' + Y(0.28 * k) + ' ' + X(3.0) + ' ' + Y(0.55 * k),
            'Q ' + X(3.02) + ' ' + Y(0.86 * k) + ' ' + X(2.76) + ' ' + Y(1.0 * k),
            'C ' + X(2.2) + ' ' + Y(1.2) + ' ' + X(1.3) + ' ' + Y(1.12) + ' ' + X(0.6) + ' ' + Y(1.01),
            'C ' + X(0.3) + ' ' + Y(0.97) + ' ' + X(0.1) + ' ' + Y(0.99) + ' ' + f(c) + ' ' + Y(1),
            'C 300 ' + Y(1.1) + ' 150 ' + Y(1.3) + ' 0 ' + Y(1.32),
            'Z'
        ].join(' ');
    }

    // Soft light along the top of the forearm and hand
    get armHighlightPath() {
        const h = this.wristHalf;
        const c = 400;
        const y = 230 - h * 0.32;
        return 'M 20 ' + (y - h * 0.15).toFixed(1) + ' Q ' + c + ' ' + (y + h * 0.05).toFixed(1) + ' ' + (c + h * 2.6).toFixed(1) + ' ' + (y - h * 0.1).toFixed(1);
    }

    get tendons() {

        const h = this.wristHalf;
        const c = 400;
        const k = 1.18;

        return [-0.62, -0.2, 0.22, 0.62].map((t, index) => ({
            key: 'td' + index,
            d: 'M ' + (c + h * 0.5).toFixed(1) + ' ' + (230 + t * h * 0.55).toFixed(1) +
               ' Q ' + (c + h * 1.6).toFixed(1) + ' ' + (230 + t * h * 0.8).toFixed(1) +
               ' ' + (c + h * 2.82).toFixed(1) + ' ' + (230 + t * h * k).toFixed(1)
        }));
    }

    get knuckles() {

        const h = this.wristHalf;
        const c = 400;
        const k = 1.18;

        return [[2.98, -0.74], [3.06, -0.29], [3.05, 0.16], [2.95, 0.6]].map((pt, index) => ({
            key: 'kn' + index,
            cx: (c + pt[0] * h).toFixed(1),
            cy: (230 + pt[1] * h * k).toFixed(1),
            r: (h * 0.13).toFixed(1)
        }));
    }

    get armFill() {
        return 'fill:' + this.skinColor + ';';
    }

    get rimWidth() {
        return (this.wristHalf * 0.34).toFixed(1);
    }

    get highlightWidth() {
        return (this.wristHalf * 0.55).toFixed(1);
    }

    // Overlay (watch + strap) in % of the 900 x 460 canvas
    get watchOnWristStyle() {
        const size = this.caseMm * 3.6;
        return 'width:' + ((size / 900) * 100).toFixed(2) + '%;';
    }

    get strapStyle() {
        const width = this.caseMm * 0.5 * 3.6;
        const height = this.wristHalf * 2 * 1.03;
        return 'width:' + ((width / 900) * 100).toFixed(2) + '%;height:' + ((height / 460) * 100).toFixed(2) + '%;';
    }

    get discFaceStyle() {
        return this.imageSrc ? 'background-image:url("' + this.imageSrc + '");' : '';
    }

    get strapClass() {
        const material = norm((this.product && (this.product.strapMaterial || this.product.caseMaterial)) || '');
        if (/gold/.test(material)) { return 'strap is-gold'; }
        if (/steel|titanium|silver|platinum/.test(material)) { return 'strap is-steel'; }
        return 'strap is-leather';
    }

    get skinOptions() {
        return SKIN_TONES.map(tone => ({
            ...tone,
            style: 'background:' + tone.color + ';',
            className: tone.key === this.skinKey ? 'swatch is-on' : 'swatch',
            pressed: tone.key === this.skinKey ? 'true' : 'false'
        }));
    }

    get caseOptions() {
        return CASE_SIZES.map(size => ({
            key: 'c' + size,
            value: String(size),
            label: size + '',
            className: size === this.caseMm ? 'size is-on' : 'size',
            pressed: size === this.caseMm ? 'true' : 'false'
        }));
    }

    handleWrist(event) {
        this.wristMm = Number(event.target.value);
    }

    handleSkin(event) {
        this.skinKey = event.currentTarget.dataset.key;
    }

    handleCaseSize(event) {
        this.caseMm = Number(event.currentTarget.dataset.value);
    }


    // =========================================================
    // SIMILAR
    // =========================================================

    get hasSimilar() {
        return this.similar.length > 0;
    }

    openSimilar(event) {
        const id = event.currentTarget.dataset.id;
        if (id) {
            window.location.href = '/ujjayini/product-detail?productId=' + encodeURIComponent(id);
        }
    }


    // =========================================================
    // NAVIGATION
    // =========================================================

    goToWatches() {
        window.location.href = '/ujjayini/watches';
    }

    handlePrivateViewing() {
        this.scrollToSection('.request-anchor');
    }


    // =========================================================
    // CART + BUY NOW
    // =========================================================

    async handleAddToCart() {

        if (!this.product || !this.product.productId || this.isOutOfStock) {
            return;
        }

        if (isGuestUser) {
            this.showGuestCartModal = true;
            return;
        }

        this.isAddingToCart = true;

        try {

            await addToCart({ productId: this.product.productId, quantity: 1 });

            window.dispatchEvent(new CustomEvent('ujjayini:cartchange'));

            this.showNotificationPopup('success', 'ADDED TO CART', 'The timepiece is waiting in your cart.');

        } catch (error) {

            this.showNotificationPopup('error', 'UNABLE TO ADD', this.getErrorMessage(error));

        } finally {

            this.isAddingToCart = false;
        }
    }

    // Adds the watch only if it is not already in the cart
    // (quantity never doubles), then opens the cart.
    async handleBuyNow() {

        if (!this.product || !this.product.productId) {
            return;
        }

        if (this.isOutOfStock) {
            this.handlePrivateViewing();
            return;
        }

        if (isGuestUser) {
            this.showGuestCartModal = true;
            return;
        }

        this.isBuyingNow = true;

        try {

            let alreadyInCart = false;

            try {
                const cart = await getCurrentCart();
                alreadyInCart = !!(cart && cart.items && cart.items.some(item => item.productId === this.product.productId));
            } catch (cartError) {
                alreadyInCart = false;
            }

            if (!alreadyInCart) {
                await addToCart({ productId: this.product.productId, quantity: 1 });
                window.dispatchEvent(new CustomEvent('ujjayini:cartchange'));
            }

            window.location.href = '/ujjayini/cart';

        } catch (error) {

            this.isBuyingNow = false;
            this.showNotificationPopup('error', 'UNABLE TO CONTINUE', this.getErrorMessage(error));
        }
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
        return this.notificationType === 'error' ? 'notification is-error' : 'notification';
    }

    getErrorMessage(error) {

        const raw = (error && error.body && error.body.message) || (error && error.message) || '';

        if (!raw || /apex|exception|System\.|script-thrown|cacheable|invalid|null/i.test(raw)) {
            return FRIENDLY_ERROR;
        }

        return raw;
    }
}