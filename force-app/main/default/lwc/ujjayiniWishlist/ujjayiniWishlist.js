import { LightningElement } from 'lwc';

import isGuestUser from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

import getWishlistItems
    from '@salesforce/apex/UJJAYINIWishlistController.getWishlistItems';

import removeFromWishlist
    from '@salesforce/apex/UJJAYINIWishlistController.removeFromWishlist';

import getSpecs
    from '@salesforce/apex/UJJAYINIWishlistSpecsController.getSpecs';

import addToCart
    from '@salesforce/apex/UJJAYINICartController.addToCart';

import wishlistCat
    from '@salesforce/resourceUrl/UJJAYINI_Wishlist_Cat';


const PRICE = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
});

const FRIENDLY_ERROR =
    'We could not open your vitrine just now. Please try again in a moment.';

const DRAG_THRESHOLD = 8;
const MAGNET = 46;

const SPEC_FIELDS = [
    'productCode', 'brand', 'modelNumber', 'caseMaterial', 'strapMaterial',
    'movement', 'dialColor', 'waterResistance', 'edition', 'warranty'
];

const COMPARE_ROWS = [
    ['COLLECTION', 'collectionName'],
    ['BRAND', 'brand'],
    ['MOVEMENT', 'movement'],
    ['CASE', 'caseMaterial'],
    ['STRAP', 'strapMaterial'],
    ['DIAL', 'dialColor'],
    ['WATER RESISTANCE', 'waterResistance'],
    ['EDITION', 'edition'],
    ['WARRANTY', 'warranty'],
    ['MODEL', 'modelNumber'],
    ['REFERENCE', 'productCode']
];


export default class UjjayiniWishlist extends LightningElement {

    items = [];

    isLoading = true;
    hasError = false;

    busyId;
    leavingIds = [];

    filter = 'ALL';

    compareIds = [];
    drawerOpen = false;

    // Drag and drop
    dragId;
    dragImage;
    hoverTargetId;
    overDock = false;

    toastTitle;
    toastMessage;
    toastIsError = false;

    _toastTimer;
    _before;
    _flip = false;
    _pending;
    _justDragged = false;
    _listening = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        if (isGuestUser) {
            this.isLoading = false;
            return;
        }

        this.load();

        if (!this._listening) {
            window.addEventListener('pageshow', this.handlePageShow);
            this._listening = true;
        }
    }

    disconnectedCallback() {

        window.removeEventListener('pageshow', this.handlePageShow);
        this._listening = false;

        this.stopDragListeners();
        this.clearPending();
        clearTimeout(this._toastTimer);
    }

    renderedCallback() {

        if (this._flip) {
            this._flip = false;
            this.playFlip();
        }
    }

    handlePageShow = event => {
        if (event.persisted) {
            this.load();
        }
    };

    async load() {

        this.isLoading = this.items.length === 0;
        this.hasError = false;

        try {

            const data = (await getWishlistItems()) || [];
            const specs = await this.loadSpecs(data);

            this.items = data.map((item, index) => {

                const spec = specs[item.productId] || {};
                const merged = { ...item };

                // Fill every blank detail from the product record.
                SPEC_FIELDS.forEach(field => {
                    if (!merged[field] && spec[field]) {
                        merged[field] = spec[field];
                    }
                });

                return {
                    ...merged,
                    index: String(index + 1).padStart(2, '0'),
                    formattedPrice: item.price === null || item.price === undefined
                        ? 'Price on request'
                        : PRICE.format(item.price),
                    hasImage: !!item.productImageUrl,
                    enterStyle: 'animation-delay: ' + Math.min(index, 8) * 80 + 'ms;'
                };
            });

            const valid = new Set(this.items.map(item => item.productId));
            this.compareIds = this.compareIds.filter(id => valid.has(id));

        } catch (error) {

            this.hasError = true;

        } finally {

            this.isLoading = false;
        }
    }

    // Details are a bonus: if they fail, the wishlist still opens.
    async loadSpecs(data) {

        const ids = data.map(item => item.productId).filter(id => id);

        if (!ids.length) {
            return {};
        }

        try {

            const rows = (await getSpecs({ productIds: ids })) || [];
            const byId = {};

            rows.forEach(row => {
                byId[row.productId] = row;
            });

            return byId;

        } catch (error) {

            return {};
        }
    }


    // =========================================================
    // VIEW DATA
    // =========================================================

    get isGuest() {
        return isGuestUser;
    }

    get backgroundUrl() {
        return 'background-image: url("' + wishlistCat + '");';
    }

    get sitePrefix() {
        return (basePath || '/ujjayini').replace(/\/s$/i, '');
    }

    get pageClass() {
        return this.dragId ? 'page is-dragging' : 'page';
    }

    get hasItems() {
        return !this.isLoading && !this.hasError && this.items.length > 0;
    }

    get isEmpty() {
        return !isGuestUser && !this.isLoading && !this.hasError && this.items.length === 0;
    }

    get friendlyError() {
        return FRIENDLY_ERROR;
    }

    get countValue() {
        return String(this.items.length).padStart(2, '0');
    }

    get countWord() {
        return this.items.length === 1 ? 'TIMEPIECE' : 'TIMEPIECES';
    }

    get filters() {

        const movements = [];

        this.items.forEach(item => {
            if (item.movement && !movements.includes(item.movement)) {
                movements.push(item.movement);
            }
        });

        if (movements.length < 2) {
            return [];
        }

        return ['ALL', ...movements].map(value => ({
            value,
            label: value.toUpperCase(),
            className: value === this.filter ? 'filter is-active' : 'filter'
        }));
    }

    get hasFilters() {
        return this.filters.length > 0;
    }

    get cards() {

        return this.items
            .filter(item => this.filter === 'ALL' || item.movement === this.filter)
            .map(item => {

                const id = item.productId;
                const comparing = this.compareIds.includes(id);

                let className = 'card';

                if (comparing) { className += ' is-comparing'; }
                if (this.leavingIds.includes(id)) { className += ' is-leaving'; }
                if (this.dragId === id) { className += ' is-dragged'; }
                if (this.hoverTargetId === id) { className += ' is-target'; }

                return {
                    ...item,
                    className,
                    isBusy: this.busyId === id || this.leavingIds.includes(id),
                    compareLabel: comparing ? '✓ IN COMPARISON' : 'COMPARE',
                    compareClass: comparing ? 'compare-toggle is-on' : 'compare-toggle',
                    comparePressed: comparing ? 'true' : 'false'
                };
            });
    }


    // =========================================================
    // COMPARE TRAY + DRAWER
    // =========================================================

    get showDock() {
        return this.hasItems && this.items.length >= 2;
    }

    get dockClass() {

        let className = 'dock';

        if (this.dragId) { className += ' is-awake'; }
        if (this.overDock) { className += ' is-over'; }

        return className;
    }

    get dockSlots() {

        return [0, 1].map(index => {

            const item = this.items.find(entry => entry.productId === this.compareIds[index]);

            return {
                key: 'slot' + index,
                filled: !!item,
                image: item ? item.productImageUrl : null,
                name: item ? item.productName : '',
                productId: item ? item.productId : '',
                className: item ? 'slot is-filled' : 'slot'
            };
        });
    }

    get dockLabel() {

        if (this.dragId) {
            return 'RELEASE HERE';
        }

        if (this.compareIds.length === 2) {
            return 'OPEN COMPARISON';
        }

        if (this.compareIds.length === 1) {
            return 'ONE MORE TO COMPARE';
        }

        return 'DRAG TWO HERE TO COMPARE';
    }

    get canOpenCompare() {
        return this.compareIds.length === 2;
    }

    get dockDisabled() {
        return !this.canOpenCompare;
    }

    get showCompare() {
        return this.drawerOpen && this.compareIds.length === 2;
    }

    get duel() {

        const pair = this.compareIds
            .map(id => this.items.find(item => item.productId === id))
            .filter(item => item);

        if (pair.length !== 2) {
            return null;
        }

        const [left, right] = pair;
        const max = Math.max(left.price || 0, right.price || 0, 1);

        return {
            left,
            right,
            leftBar: 'width: ' + Math.round(((left.price || 0) / max) * 100) + '%;',
            rightBar: 'width: ' + Math.round(((right.price || 0) / max) * 100) + '%;',
            rows: COMPARE_ROWS
                // Hide a row only when neither watch has that detail.
                .filter(([, field]) => left[field] || right[field])
                .map(([label, field]) => {

                    const a = left[field] || '—';
                    const b = right[field] || '—';
                    const same = a !== '—' && String(a).toLowerCase() === String(b).toLowerCase();

                    return {
                        key: field,
                        label,
                        left: a,
                        right: b,
                        connector: same ? '=' : '·',
                        className: same ? 'row is-same' : 'row'
                    };
                })
        };
    }

    get toastClass() {
        return this.toastIsError ? 'toast is-error' : 'toast';
    }


    // =========================================================
    // DRAG TO COMPARE
    // Mouse: drag the glass case. Touch: drag the ⠿ handle.
    // =========================================================

    handleCasePointerDown(event) {

        if (event.pointerType !== 'mouse' || event.button !== 0) {
            return;
        }

        this._pending = {
            id: event.currentTarget.dataset.id,
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

        const moved = Math.hypot(event.clientX - this._pending.x, event.clientY - this._pending.y);

        if (moved > DRAG_THRESHOLD) {
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
        this.beginDrag(event.currentTarget.dataset.id, event.clientX, event.clientY);
    }

    beginDrag(id, x, y) {

        const item = this.items.find(entry => entry.productId === id);

        if (!item) {
            return;
        }

        this.dragId = id;
        this.dragImage = item.productImageUrl;
        this.hoverTargetId = undefined;
        this.overDock = false;

        window.addEventListener('pointermove', this.onDragMove);
        window.addEventListener('pointerup', this.onDragEnd);
        window.addEventListener('pointercancel', this.onDragEnd);

        requestAnimationFrame(() => this.moveGhost(x, y, null));
    }

    onDragMove = event => {

        if (!this.dragId) {
            return;
        }

        event.preventDefault();

        const x = event.clientX;
        const y = event.clientY;

        let target = null;
        let best = Infinity;

        this.template.querySelectorAll('.card').forEach(el => {

            const id = el.dataset.id;

            if (id === this.dragId) {
                return;
            }

            const r = el.getBoundingClientRect();

            if (x > r.left - MAGNET && x < r.right + MAGNET && y > r.top - MAGNET && y < r.bottom + MAGNET) {

                const cx = r.left + r.width / 2;
                const cy = r.top + r.height / 3;
                const distance = Math.hypot(x - cx, y - cy);

                if (distance < best) {
                    best = distance;
                    target = { id, cx, cy };
                }
            }
        });

        const dock = this.template.querySelector('.dock');
        let overDock = false;

        if (dock) {
            const r = dock.getBoundingClientRect();
            overDock = x > r.left - 20 && x < r.right + 20 && y > r.top - 30 && y < r.bottom + 20;
        }

        if (overDock) {
            target = null;
        }

        const targetId = target ? target.id : undefined;

        if (targetId !== this.hoverTargetId) {
            this.hoverTargetId = targetId;
        }

        if (overDock !== this.overDock) {
            this.overDock = overDock;
        }

        this.moveGhost(x, y, target);

        const edge = 90;

        if (y < edge) {
            window.scrollBy(0, -14);
        } else if (y > window.innerHeight - edge) {
            window.scrollBy(0, 14);
        }
    };

    onDragEnd = () => {

        const dragged = this.dragId;
        const target = this.hoverTargetId;
        const dock = this.overDock;

        this.stopDragListeners();

        this.dragId = undefined;
        this.hoverTargetId = undefined;
        this.overDock = false;

        this._justDragged = true;
        setTimeout(() => { this._justDragged = false; }, 80);

        if (!dragged) {
            return;
        }

        if (target) {
            this.compareIds = [dragged, target];
            this.drawerOpen = true;
            return;
        }

        if (dock) {
            this.addToCompare(dragged);
        }
    };

    stopDragListeners() {
        window.removeEventListener('pointermove', this.onDragMove);
        window.removeEventListener('pointerup', this.onDragEnd);
        window.removeEventListener('pointercancel', this.onDragEnd);
    }

    moveGhost(x, y, target) {

        const ghost = this.template.querySelector('.ghost');

        if (!ghost) {
            return;
        }

        let gx = x;
        let gy = y;
        let scale = 1;

        if (target) {
            gx = x + (target.cx - x) * 0.35;
            gy = y + (target.cy - y) * 0.35;
            scale = 0.82;
        }

        ghost.style.transform =
            'translate3d(' + gx.toFixed(1) + 'px,' + gy.toFixed(1) + 'px,0) ' +
            'translate(-50%,-50%) rotate(-7deg) scale(' + scale + ')';
    }

    addToCompare(id) {

        if (this.compareIds.includes(id)) {
            return;
        }

        this.compareIds = [...this.compareIds, id].slice(-2);

        if (this.compareIds.length === 2) {
            this.drawerOpen = true;
        }
    }

    toggleCompare(event) {

        const id = event.currentTarget.dataset.id;

        if (this.compareIds.includes(id)) {
            this.compareIds = this.compareIds.filter(value => value !== id);
            return;
        }

        this.addToCompare(id);
    }

    removeFromTray(event) {
        const id = event.currentTarget.dataset.id;
        this.compareIds = this.compareIds.filter(value => value !== id);
    }

    openCompare() {
        if (this.canOpenCompare) {
            this.drawerOpen = true;
        }
    }

    closeCompare() {
        this.drawerOpen = false;
    }

    clearCompare() {
        this.drawerOpen = false;
        this.compareIds = [];
    }

    stopPropagation(event) {
        event.stopPropagation();
    }


    // =========================================================
    // 3D TILT + LIGHT SWEEP
    // =========================================================

    handleTilt(event) {

        if (this.dragId || event.pointerType !== 'mouse') {
            return;
        }

        const el = event.currentTarget;
        const r = el.getBoundingClientRect();
        const px = (event.clientX - r.left) / r.width;
        const py = (event.clientY - r.top) / r.height;

        el.style.setProperty('--mx', (px * 100).toFixed(1) + '%');
        el.style.setProperty('--my', (py * 100).toFixed(1) + '%');
        el.style.setProperty('--shine', '1');
        el.style.transform =
            'perspective(900px) rotateX(' + ((0.5 - py) * 8).toFixed(2) + 'deg) ' +
            'rotateY(' + ((px - 0.5) * 10).toFixed(2) + 'deg)';
    }

    handleTiltLeave(event) {
        const el = event.currentTarget;
        el.style.setProperty('--shine', '0');
        el.style.transform = '';
    }


    // =========================================================
    // FLIP: remaining cards glide into place
    // =========================================================

    capturePositions() {

        if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
            return;
        }

        this._before = new Map();

        this.template.querySelectorAll('.card').forEach(el => {
            this._before.set(el.dataset.id, el.getBoundingClientRect());
        });

        this._flip = true;
    }

    playFlip() {

        if (!this._before) {
            return;
        }

        let order = 0;

        this.template.querySelectorAll('.card').forEach(el => {

            const before = this._before.get(el.dataset.id);

            if (!before) {
                return;
            }

            const now = el.getBoundingClientRect();
            const dx = before.left - now.left;
            const dy = before.top - now.top;

            if (Math.abs(dx) < 1 && Math.abs(dy) < 1) {
                return;
            }

            const delay = order++ * 55;

            el.style.transition = 'none';
            el.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';

            requestAnimationFrame(() => {
                requestAnimationFrame(() => {
                    el.style.transition = 'transform 0.8s cubic-bezier(0.34, 1.5, 0.64, 1) ' + delay + 'ms';
                    el.style.transform = '';
                });
            });
        });

        this._before = undefined;
    }


    // =========================================================
    // ACTIONS
    // =========================================================

    handleFilter(event) {
        this.capturePositions();
        this.filter = event.currentTarget.dataset.value;
    }

    async handleRemove(event) {

        const id = event.currentTarget.dataset.id;

        if (!id || this.busyId) {
            return;
        }

        this.busyId = id;
        this.leavingIds = [...this.leavingIds, id];

        try {

            await Promise.all([
                removeFromWishlist({ productId: id }),
                new Promise(resolve => setTimeout(resolve, 420))
            ]);

            this.capturePositions();

            this.items = this.items.filter(item => item.productId !== id);
            this.compareIds = this.compareIds.filter(value => value !== id);

            if (this.filter !== 'ALL' && !this.items.some(item => item.movement === this.filter)) {
                this.filter = 'ALL';
            }

            window.dispatchEvent(new CustomEvent('ujjayini:wishlistchange'));

            this.showToast('REMOVED', 'The timepiece has left your vitrine.');

        } catch (error) {

            this.showToast('UNABLE TO REMOVE', FRIENDLY_ERROR, true);

        } finally {

            this.leavingIds = this.leavingIds.filter(value => value !== id);
            this.busyId = undefined;
        }
    }

    async handleAddToCart(event) {

        const id = event.currentTarget.dataset.id;

        if (!id || this.busyId) {
            return;
        }

        this.busyId = id;

        try {

            await addToCart({ productId: id, quantity: 1 });

            window.dispatchEvent(new CustomEvent('ujjayini:cartchange'));

            this.showToast('ADDED TO CART', 'The timepiece is waiting in your cart.');

        } catch (error) {

            const raw = (error && error.body && error.body.message) || '';

            this.showToast(
                'UNABLE TO ADD',
                !raw || /apex|exception|System\.|cacheable/i.test(raw) ? FRIENDLY_ERROR : raw,
                true
            );

        } finally {

            this.busyId = undefined;
        }
    }

    viewProduct(event) {

        if (this._justDragged) {
            return;
        }

        const id = event.currentTarget.dataset.id;

        if (id) {
            window.location.href =
                this.sitePrefix + '/product-detail?productId=' + encodeURIComponent(id);
        }
    }

    scrollToVitrine() {

        const target = this.template.querySelector('.vitrine');

        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    goToWatches() {
        window.location.href = this.sitePrefix + '/watches';
    }

    goToLogin() {
        window.location.href =
            this.sitePrefix + '/login?startURL=' + encodeURIComponent(this.sitePrefix + '/wishlist');
    }

    goToRegister() {
        window.location.href = this.sitePrefix + '/SelfRegister';
    }

    retry() {
        this.load();
    }

    showToast(title, message, isError) {

        clearTimeout(this._toastTimer);

        this.toastTitle = title;
        this.toastMessage = message;
        this.toastIsError = !!isError;

        this._toastTimer = setTimeout(() => {
            this.toastTitle = undefined;
        }, 3800);
    }

    closeToast() {
        this.toastTitle = undefined;
    }
}