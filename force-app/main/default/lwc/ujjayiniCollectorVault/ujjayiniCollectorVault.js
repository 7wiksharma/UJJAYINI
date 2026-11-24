import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getMyAssets
    from '@salesforce/apex/UJJAYINICollectorVaultController.getMyAssets';

import verifyPayment
    from '@salesforce/apex/UJJAYINICollectorVaultController.verifyPayment';

import getMyWarranties
    from '@salesforce/apex/UJJAYINIWarrantyController.getMyWarranties';

import getMyCertificate
    from '@salesforce/apex/UJJAYINICertificateController.getMyCertificate';


// Check every 2 seconds, at most 15 times (about 30 seconds).
const POLL_INTERVAL_MS = 2000;
const MAX_POLL_ATTEMPTS = 45; // 45 x 2 s = 90 seconds

const BANNER_COPY = {
    VERIFYING: {
        eyebrow: 'CONFIRMING YOUR PAYMENT',
        title: 'One moment.',
        message: 'We are verifying your payment with our records.'
    },
    PREPARING: {
        eyebrow: 'PAYMENT RECEIVED',
        title: 'Your timepiece is being prepared.',
        message: 'It is being registered in your Collector\'s Vault.'
    },
    REGISTERED: {
        eyebrow: 'WELCOME TO YOUR COLLECTION',
        title: 'Your timepiece is now in the Vault.',
        message: 'Its ownership record and certificate are now part of your collection.'
    },
    TIMEOUT_CONFIRMED: {
        eyebrow: 'PAYMENT CONFIRMED',
        title: 'Almost there.',
        message: 'Your timepiece is still being registered in the Vault. Please refresh shortly.'
    },
    TIMEOUT_UNCONFIRMED: {
        eyebrow: 'PAYMENT UNDER CONFIRMATION',
        title: 'We have not received confirmation yet.',
        message: 'Your timepiece will appear in the Vault as soon as your payment is confirmed. Please refresh shortly.'
    }
};

const FRIENDLY_ERROR = 'The vault is taking a moment to open. Please refresh the page.';
const CERT_ERROR = 'The certificate could not be prepared just now. Please try again in a moment.';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const INR = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
});

const DAY = 24 * 60 * 60 * 1000;


function norm(value) {
    return (value || '')
        .toString()
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .toLowerCase()
        .trim();
}

function parseDate(value) {

    if (!value) {
        return null;
    }

    const parts = String(value).split('-').map(Number);

    if (parts.length !== 3 || parts.some(isNaN)) {
        return null;
    }

    return new Date(parts[0], parts[1] - 1, parts[2]);
}

function formatDate(value) {
    const date = value instanceof Date ? value : parseDate(value);
    return date ? date.getDate() + ' ' + MONTHS[date.getMonth()] + ' ' + date.getFullYear() : '—';
}

function cloudinary(url, transform) {

    if (!url || url.indexOf('res.cloudinary.com') === -1 || url.indexOf('/upload/') === -1) {
        return url;
    }

    return url.replace('/upload/', '/upload/' + transform + '/');
}


export default class UjjayiniCollectorVault extends LightningElement {

    assets = [];
    warranties = [];
    isLoading = true;
    errorMessage;
    wiredAssetsResult;

    // Detail panel
    openId;

    // Certificate download
    downloadingId;

    // Toast
    toastTitle;
    toastMessage;
    toastIsError = false;
    _toastTimer;

    // Post-payment confirmation
    paymentPhase = '';
    _paymentLinkId;
    _paymentConfirmed = false;
    _pollAttempts = 0;
    _pollTimer;
    _dismissTimer;
    _verifyInFlight = false;
    _disposed = false;

    // Black hole
    _canvas;
    _ctx;
    _frame;
    _particles = [];
    _stars = [];
    _w = 0;
    _h = 0;
    _dpr = 1;
    _lastScroll = 0;
    _warp = 0;
    _started = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {
        this.startPaymentVerificationIfNeeded();
        window.addEventListener('resize', this.handleResize, { passive: true });
        window.addEventListener('scroll', this.handleScroll, { passive: true });
    }

    disconnectedCallback() {

        this._disposed = true;
        this.stopPolling();

        clearTimeout(this._dismissTimer);
        clearTimeout(this._toastTimer);

        window.removeEventListener('resize', this.handleResize);
        window.removeEventListener('scroll', this.handleScroll);

        if (this._frame) {
            cancelAnimationFrame(this._frame);
        }
    }

    renderedCallback() {

        if (this._started) {
            return;
        }

        const canvas = this.template.querySelector('canvas.horizon');

        if (!canvas || !canvas.getContext) {
            return;
        }

        this._started = true;
        this._canvas = canvas;
        this._ctx = canvas.getContext('2d');

        this.resizeCanvas();
        this.seedParticles();

        if (this.reduceMotion) {
            this.drawFrame(0);
            return;
        }

        const loop = time => {
            if (this._disposed) {
                return;
            }
            this.drawFrame(time);
            this._frame = requestAnimationFrame(loop);
        };

        this._frame = requestAnimationFrame(loop);
    }

    get reduceMotion() {
        return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    }


    // =========================================================
    // THE EVENT HORIZON (canvas)
    // =========================================================

    handleResize = () => {
        if (this._canvas) {
            this.resizeCanvas();
            this.seedParticles();
            if (this.reduceMotion) {
                this.drawFrame(0);
            }
        }
    };

    handleScroll = () => {
        const y = window.scrollY || 0;
        const delta = Math.abs(y - this._lastScroll);
        this._lastScroll = y;
        this._warp = Math.min(1, this._warp + delta / 260);
    };

    resizeCanvas() {

        this._dpr = Math.min(1.5, window.devicePixelRatio || 1);
        this._w = window.innerWidth || 1200;
        this._h = window.innerHeight || 800;

        this._canvas.width = Math.floor(this._w * this._dpr);
        this._canvas.height = Math.floor(this._h * this._dpr);
        this._ctx.setTransform(this._dpr, 0, 0, this._dpr, 0, 0);
    }

    get holeRadius() {
        return Math.max(54, Math.min(this._w, this._h) * 0.11);
    }

    seedParticles() {

        const R = this.holeRadius;
        const count = this._w < 760 ? 420 : 900;

        this._particles = [];

        for (let i = 0; i < count; i++) {
            this._particles.push(this.newParticle(R, true));
        }

        this._stars = [];

        for (let i = 0; i < 170; i++) {
            this._stars.push({
                x: Math.random(),
                y: Math.random(),
                r: Math.random() * 1.2 + 0.2,
                t: Math.random() * Math.PI * 2
            });
        }
    }

    newParticle(R, anywhere) {

        const radius = anywhere
            ? R * (1.18 + Math.pow(Math.random(), 1.6) * 3.4)
            : R * (3.6 + Math.random() * 1.0);

        const hot = Math.random();

        return {
            r: radius,
            a: Math.random() * Math.PI * 2,
            w: 0.5 + Math.random() * 1.6,
            hue: hot > 0.94 ? 'cyan' : (hot > 0.88 ? 'rose' : 'amber'),
            alpha: 0.25 + Math.random() * 0.75
        };
    }

    particleColor(p, alpha) {

        if (p.hue === 'cyan') {
            return 'rgba(140, 240, 255,' + alpha + ')';
        }

        if (p.hue === 'rose') {
            return 'rgba(255, 140, 170,' + alpha + ')';
        }

        // Hotter (whiter) near the horizon
        const heat = Math.max(0, Math.min(1, 1 - (p.r / this.holeRadius - 1.2) / 3));
        const g = Math.round(150 + heat * 90);
        const b = Math.round(60 + heat * 150);

        return 'rgba(255,' + g + ',' + b + ',' + alpha + ')';
    }

    drawFrame(time) {

        const ctx = this._ctx;
        const w = this._w;
        const h = this._h;

        if (!ctx || !w) {
            return;
        }

        const scroll = Math.min(1, (window.scrollY || 0) / h);
        const R = this.holeRadius * (1 + scroll * 0.25);
        const cx = w * (w < 760 ? 0.5 : 0.68 - scroll * 0.18);
        const cy = h * (w < 760 ? 0.34 : 0.46);
        const tilt = -0.22;
        const squash = 0.3;
        const speed = this.reduceMotion ? 0 : 1;

        this._warp *= 0.92;

        // Base
        ctx.globalCompositeOperation = 'source-over';
        ctx.fillStyle = '#050407';
        ctx.fillRect(0, 0, w, h);

        // Stars (pulled toward the centre by the warp)
        ctx.fillStyle = '#fff6e5';
        this._stars.forEach(star => {
            star.t += 0.02 * speed;
            const sx = star.x * w;
            const sy = star.y * h;
            const pull = 1 - this._warp * 0.08;
            const x = cx + (sx - cx) * pull;
            const y = cy + (sy - cy) * pull;
            ctx.globalAlpha = (0.35 + Math.sin(star.t) * 0.25) * (1 - scroll * 0.4);
            ctx.fillRect(x, y, star.r, star.r);
        });
        ctx.globalAlpha = 1;

        // Ambient glow
        const glow = ctx.createRadialGradient(cx, cy, R * 0.8, cx, cy, R * 6);
        glow.addColorStop(0, 'rgba(255, 170, 70, 0.35)');
        glow.addColorStop(0.35, 'rgba(200, 90, 40, 0.12)');
        glow.addColorStop(1, 'rgba(0, 0, 0, 0)');
        ctx.fillStyle = glow;
        ctx.fillRect(0, 0, w, h);

        // Warp streaks while scrolling
        if (this._warp > 0.02) {
            ctx.globalCompositeOperation = 'lighter';
            for (let i = 0; i < 60; i++) {
                const ang = (i / 60) * Math.PI * 2 + i * 0.37;
                const inner = R * (2 + (i % 7));
                const len = 80 + (i % 5) * 60;
                ctx.strokeStyle = 'rgba(255, 190, 110,' + (this._warp * 0.35).toFixed(3) + ')';
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(ang) * inner, cy + Math.sin(ang) * inner);
                ctx.lineTo(cx + Math.cos(ang) * (inner + len * (1 + this._warp)), cy + Math.sin(ang) * (inner + len * (1 + this._warp)));
                ctx.stroke();
            }
            ctx.globalCompositeOperation = 'source-over';
        }

        // Disk: back half first
        this.advanceParticles(R, speed);
        this.drawDisk(ctx, cx, cy, R, tilt, squash, false);

        // Lensed halo (light bent over the top of the hole)
        ctx.globalCompositeOperation = 'lighter';
        for (let i = 0; i < 5; i++) {
            ctx.beginPath();
            ctx.arc(cx, cy, R * (1.1 + i * 0.07), Math.PI * 1.02, Math.PI * 1.98);
            ctx.strokeStyle = 'rgba(255, 200, 120,' + (0.32 - i * 0.055) + ')';
            ctx.lineWidth = R * 0.07;
            ctx.stroke();
        }
        ctx.globalCompositeOperation = 'source-over';

        // Event horizon
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, Math.PI * 2);
        ctx.fillStyle = '#000';
        ctx.fill();

        // Photon ring (with a faint neon fringe)
        ctx.save();
        ctx.shadowColor = 'rgba(255, 210, 140, 0.9)';
        ctx.shadowBlur = 24;
        ctx.beginPath();
        ctx.arc(cx, cy, R * 1.015, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(255, 236, 200, 0.95)';
        ctx.lineWidth = 1.6;
        ctx.stroke();
        ctx.restore();

        ctx.beginPath();
        ctx.arc(cx, cy, R * 0.985, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(120, 235, 255, 0.18)';
        ctx.lineWidth = 1;
        ctx.stroke();

        // Disk: front half over the hole
        this.drawDisk(ctx, cx, cy, R, tilt, squash, true);

        // The clock that orbits the singularity
        this.drawClock(ctx, cx, cy, R, time);
    }

    advanceParticles(R, speed) {

        for (let i = 0; i < this._particles.length; i++) {

            const p = this._particles[i];

            p.a += 0.9 * Math.pow(R / p.r, 1.5) * 0.02 * speed;
            p.r -= 0.06 * speed;

            if (p.r < R * 1.12) {
                this._particles[i] = this.newParticle(R, false);
            }
        }
    }

    drawDisk(ctx, cx, cy, R, tilt, squash, front) {

        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(tilt);
        ctx.scale(1, squash);
        ctx.globalCompositeOperation = 'lighter';
        ctx.lineCap = 'round';

        this._particles.forEach(p => {

            const isFront = Math.sin(p.a) > 0;

            if (isFront !== front) {
                return;
            }

            const omega = 0.9 * Math.pow(R / p.r, 1.5) * 0.02;
            const trail = Math.min(0.5, omega * 10 + 0.05);

            ctx.beginPath();
            ctx.arc(0, 0, p.r, p.a - trail, p.a);
            ctx.strokeStyle = this.particleColor(p, Math.min(1, p.alpha * 1.05).toFixed(3));
            ctx.lineWidth = p.w * 1.25;
            ctx.stroke();
        });

        // Soft luminous body of the disk
        ctx.beginPath();
        ctx.arc(0, 0, R * 1.9, front ? 0 : Math.PI, front ? Math.PI : Math.PI * 2);
        ctx.strokeStyle = 'rgba(255, 160, 80, 0.10)';
        ctx.lineWidth = R * 1.1;
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(0, 0, R * 1.45, front ? 0 : Math.PI, front ? Math.PI : Math.PI * 2);
        ctx.strokeStyle = 'rgba(255, 200, 130, 0.16)';
        ctx.lineWidth = R * 0.45;
        ctx.stroke();

        // Bright inner rim of the disk
        ctx.beginPath();
        ctx.arc(0, 0, R * 1.22, front ? 0 : Math.PI, front ? Math.PI : Math.PI * 2);
        ctx.strokeStyle = 'rgba(255, 220, 160, 0.55)';
        ctx.lineWidth = R * 0.12;
        ctx.stroke();

        ctx.restore();
        ctx.globalCompositeOperation = 'source-over';
    }

    drawClock(ctx, cx, cy, R, time) {

        const radius = R * 4.6;
        const spin = (time || 0) / 240000;

        ctx.save();
        ctx.translate(cx, cy);

        for (let i = 0; i < 60; i++) {

            const ang = (i / 60) * Math.PI * 2 + spin;
            const major = i % 5 === 0;
            const inner = radius - (major ? 16 : 7);

            ctx.beginPath();
            ctx.moveTo(Math.cos(ang) * inner, Math.sin(ang) * inner);
            ctx.lineTo(Math.cos(ang) * radius, Math.sin(ang) * radius);
            ctx.strokeStyle = major ? 'rgba(255, 214, 150, 0.45)' : 'rgba(255, 240, 220, 0.14)';
            ctx.lineWidth = major ? 1.6 : 1;
            ctx.stroke();
        }

        // Seconds hand sweeping through time
        const now = new Date();
        const seconds = now.getSeconds() + now.getMilliseconds() / 1000;
        const hand = (seconds / 60) * Math.PI * 2 - Math.PI / 2;

        ctx.beginPath();
        ctx.moveTo(Math.cos(hand) * R * 1.5, Math.sin(hand) * R * 1.5);
        ctx.lineTo(Math.cos(hand) * (radius + 10), Math.sin(hand) * (radius + 10));
        ctx.strokeStyle = 'rgba(255, 150, 90, 0.75)';
        ctx.lineWidth = 1.4;
        ctx.shadowColor = 'rgba(255, 140, 80, 0.9)';
        ctx.shadowBlur = 10;
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(Math.cos(hand) * (radius + 10), Math.sin(hand) * (radius + 10), 3, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(255, 190, 120, 1)';
        ctx.fill();

        ctx.restore();
    }


    // =========================================================
    // ASSETS + WARRANTIES
    // =========================================================

    @wire(getMyAssets)
    wiredAssets(result) {

        this.wiredAssetsResult = result;

        const { data, error } = result;

        if (data) {
            this.assets = data.map(asset => ({ ...asset }));
            this.errorMessage = undefined;
            this.loadWarranties();
        } else if (error) {
            this.isLoading = false;
            this.errorMessage = FRIENDLY_ERROR;
        }
    }

    async loadWarranties() {

        try {
            this.warranties = (await getMyWarranties()) || [];
        } catch (error) {
            // The collection still shows without warranty details.
            this.warranties = [];
        } finally {
            this.isLoading = false;
        }
    }

    warrantyFor(assetId) {
        return this.warranties.find(item => item.assetId === assetId) || null;
    }

    themeKey(collection) {
        const key = norm(collection);
        return key === 'indranila' || key === 'hiranya' || key === 'ayas' ? key : 'house';
    }

    decorate(asset, index) {

        const warranty = this.warrantyFor(asset.assetId);
        const today = new Date();

        let warrantyLabel = 'WARRANTY DETAILS PENDING';
        let warrantyShort = '—';
        let barStyle = 'width:0%;';
        let warrantyClass = 'warranty-state';
        let hasWarranty = false;
        let timelineStyle = 'left:0%;';

        if (warranty) {

            hasWarranty = true;

            const start = parseDate(warranty.startDate);
            const end = parseDate(warranty.endDate);
            const status = (warranty.status || '').toUpperCase();

            if (status === 'VOIDED') {
                warrantyLabel = 'WARRANTY VOIDED';
                warrantyShort = 'Voided';
                warrantyClass += ' is-off';
            } else if (start && end) {

                const total = Math.max(1, end - start);
                const left = end - today;
                const used = Math.min(1, Math.max(0, (today - start) / total));

                barStyle = 'width:' + ((1 - used) * 100).toFixed(1) + '%;';
                timelineStyle = 'left:' + (used * 100).toFixed(1) + '%;';

                if (left <= 0 || status === 'EXPIRED') {
                    warrantyLabel = 'WARRANTY COMPLETED';
                    warrantyShort = 'Completed';
                    warrantyClass += ' is-off';
                } else {
                    const months = Math.max(0, Math.round(left / (30.44 * DAY)));
                    warrantyLabel = months >= 1
                        ? months + (months === 1 ? ' MONTH' : ' MONTHS') + ' OF PROTECTION LEFT'
                        : Math.ceil(left / DAY) + ' DAYS OF PROTECTION LEFT';
                    warrantyShort = months + ' mo left';
                }
            }
        }

        const qty = asset.quantity ? Number(asset.quantity) : 1;

        return {
            ...asset,
            index: String(index + 1).padStart(2, '0'),
            className: 'drawer theme-' + this.themeKey(asset.collectionName),
            imageStyle: asset.productImageUrl
                ? 'background-image:url("' + cloudinary(asset.productImageUrl, 'f_auto,q_auto,c_limit,w_900') + '");'
                : '',
            imageLargeStyle: asset.productImageUrl
                ? 'background-image:url("' + cloudinary(asset.productImageUrl, 'f_auto,q_auto,c_limit,w_1400') + '");'
                : '',
            hasImage: !!asset.productImageUrl,
            collectionLabel: asset.collectionName || 'UJJAYINI',
            acquired: formatDate(asset.purchaseDate),
            value: asset.price != null ? INR.format(asset.price) : '—',
            hasQuantity: qty > 1,
            quantityLabel: '× ' + qty,
            statusLabel: asset.status === 'Purchased' ? 'IN YOUR COLLECTION' : (asset.status || 'OWNED').toUpperCase(),
            certificateNumber: asset.certificateNumber || '—',
            warranty,
            hasWarranty,
            warrantyLabel,
            warrantyShort,
            warrantyClass,
            barStyle,
            timelineStyle,
            warrantyStart: warranty ? formatDate(warranty.startDate) : '—',
            warrantyEnd: warranty ? formatDate(warranty.endDate) : '—',
            coverage: warranty && warranty.coverageType ? warranty.coverageType : '—',
            duration: warranty && warranty.durationMonths ? warranty.durationMonths + ' months' : '—',
            warrantyNotes: warranty ? warranty.notes : null,
            certLabel: this.downloadingId === asset.assetId ? 'PREPARING…' : 'CERTIFICATE',
            isDownloading: this.downloadingId === asset.assetId,
            specs: [
                ['MOVEMENT', asset.movement],
                ['CASE', asset.caseMaterial],
                ['DIAL', asset.dialColor],
                ['MODEL', asset.modelNumber],
                ['EDITION', asset.limitedEdition
                    ? (asset.editionSize ? 'Limited · ' + asset.editionSize + ' pieces' : 'Limited edition')
                    : null]
            ]
                .filter(([, value]) => value)
                .map(([label, value]) => ({ key: label, label, value }))
        };
    }

    get cards() {
        return this.assets.map((asset, index) => this.decorate(asset, index));
    }

    get hasAssets() {
        return this.assets.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && !this.isVerifyingPayment && this.assets.length === 0;
    }

    get countLabel() {
        return String(this.assets.length).padStart(2, '0');
    }

    get countWord() {
        return this.assets.length === 1 ? 'TIMEPIECE' : 'TIMEPIECES';
    }

    get protectedCount() {
        return String(this.cards.filter(card => card.hasWarranty && card.warrantyClass === 'warranty-state').length).padStart(2, '0');
    }

    get certifiedCount() {
        return String(this.assets.filter(asset => asset.certificateNumber).length).padStart(2, '0');
    }


    // =========================================================
    // DETAIL PANEL
    // =========================================================

    get openCard() {
        return this.openId ? this.cards.find(card => card.assetId === this.openId) : null;
    }

    get showPanel() {
        return !!this.openCard;
    }

    openDetails(event) {
        this.openId = event.currentTarget.dataset.id;
    }

    closeDetails() {
        this.openId = undefined;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    goToService() {
        window.location.href = '/ujjayini/service';
    }

    goToWatches() {
        window.location.href = '/ujjayini/watches';
    }

    scrollToCollection() {
        const target = this.template.querySelector('.collection');
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }


    // =========================================================
    // CERTIFICATE DOWNLOAD
    // =========================================================

    async downloadCertificate(event) {

        event.stopPropagation();

        const assetId = event.currentTarget.dataset.id;

        if (!assetId || this.downloadingId) {
            return;
        }

        this.downloadingId = assetId;

        try {

            const file = await getMyCertificate({ assetId });

            if (!file || !file.base64) {
                throw new Error('empty');
            }

            const link = document.createElement('a');
            link.href = 'data:application/pdf;base64,' + file.base64;
            link.download = file.fileName || 'UJJAYINI-Certificate.pdf';
            link.rel = 'noopener';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            this.showToast('CERTIFICATE READY', 'Your Certificate of Authenticity has been downloaded.');

        } catch (error) {

            this.showToast('CERTIFICATE UNAVAILABLE', CERT_ERROR, true);

        } finally {

            this.downloadingId = undefined;
        }
    }

    showToast(title, message, isError) {

        clearTimeout(this._toastTimer);

        this.toastTitle = title;
        this.toastMessage = message;
        this.toastIsError = !!isError;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._toastTimer = setTimeout(() => {
            this.toastTitle = undefined;
        }, 4200);
    }

    closeToast() {
        this.toastTitle = undefined;
    }

    get toastClass() {
        return this.toastIsError ? 'toast is-error' : 'toast';
    }


    // =========================================================
    // POST-PAYMENT VERIFICATION (unchanged behaviour)
    //
    // The URL parameter is only a trigger. Salesforce decides
    // whether the payment is captured and the Asset exists.
    // =========================================================

    startPaymentVerificationIfNeeded() {

        let params;

        try {
            params = new URLSearchParams(window.location.search);
        } catch (error) {
            return;
        }

        const status = params.get('razorpay_payment_link_status');

        if (!status || status.toLowerCase() !== 'paid') {
            return;
        }

        this._paymentLinkId = params.get('razorpay_payment_link_id');
        this._paymentConfirmed = false;
        this._pollAttempts = 0;
        this.paymentPhase = 'VERIFYING';

        this.verifyPaymentOnce();
    }

    async verifyPaymentOnce() {

        if (this._disposed || this._verifyInFlight) {
            return;
        }

        this._verifyInFlight = true;
        this._pollAttempts += 1;

        let verification = null;

        try {
            verification = await verifyPayment({ paymentLinkId: this._paymentLinkId });
        } catch (error) {
            // A network hiccup must not stop the polling.
            verification = null;
        } finally {
            this._verifyInFlight = false;
        }

        if (this._disposed) {
            return;
        }

        if (verification && verification.assetReady) {
            await this.finishPaymentVerification();
            return;
        }

        if (verification && verification.paymentConfirmed) {
            this._paymentConfirmed = true;
        }

        if (this._pollAttempts >= MAX_POLL_ATTEMPTS) {
            this.paymentPhase = this._paymentConfirmed ? 'TIMEOUT_CONFIRMED' : 'TIMEOUT_UNCONFIRMED';
            return;
        }

        this.paymentPhase = this._paymentConfirmed ? 'PREPARING' : 'VERIFYING';

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._pollTimer = setTimeout(() => this.verifyPaymentOnce(), POLL_INTERVAL_MS);
    }

    async finishPaymentVerification() {

        this.stopPolling();

        try {
            if (this.wiredAssetsResult) {
                await refreshApex(this.wiredAssetsResult);
            }
        } catch (error) {
            // The wire will deliver the data on its next refresh.
        }

        if (this._disposed) {
            return;
        }

        this.paymentPhase = 'REGISTERED';
        this.removePaymentParamsFromUrl();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._dismissTimer = setTimeout(() => {
            if (this.paymentPhase === 'REGISTERED') {
                this.paymentPhase = '';
            }
        }, 12000);
    }

    stopPolling() {
        if (this._pollTimer) {
            clearTimeout(this._pollTimer);
            this._pollTimer = null;
        }
    }

    removePaymentParamsFromUrl() {

        try {

            const url = new URL(window.location.href);
            const razorpayKeys = Array.from(url.searchParams.keys()).filter(key => key.startsWith('razorpay_'));

            if (razorpayKeys.length === 0) {
                return;
            }

            razorpayKeys.forEach(key => url.searchParams.delete(key));

            window.history.replaceState(window.history.state, '', url.pathname + url.search + url.hash);

        } catch (error) {
            // Cleaning the address bar is cosmetic only.
        }
    }

    handleDismissPayment() {
        this.paymentPhase = '';
    }

    handleRefreshVault() {
        window.location.reload();
    }

    get showPaymentBanner() {
        return !!this.paymentPhase;
    }

    get isVerifyingPayment() {
        return this.paymentPhase === 'VERIFYING' || this.paymentPhase === 'PREPARING';
    }

    get isPaymentDone() {
        return !this.isVerifyingPayment;
    }

    get showRefresh() {
        return this.paymentPhase === 'TIMEOUT_CONFIRMED' || this.paymentPhase === 'TIMEOUT_UNCONFIRMED';
    }

    get paymentBannerClass() {
        return this.isVerifyingPayment ? 'payment-banner is-working' : 'payment-banner is-done';
    }

    get paymentBannerEyebrow() {
        return (BANNER_COPY[this.paymentPhase] || {}).eyebrow;
    }

    get paymentBannerTitle() {
        return (BANNER_COPY[this.paymentPhase] || {}).title;
    }

    get paymentBannerMessage() {
        return (BANNER_COPY[this.paymentPhase] || {}).message;
    }
}