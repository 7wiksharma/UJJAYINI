import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import isGuestUser from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

import getHeaderInfo
    from '@salesforce/apex/UJJAYINIHeaderController.getHeaderInfo';


const MOBILE_BREAKPOINT = 1150;


export default class UjjayiniSiteHeader extends LightningElement {

    menuOpen = false;
    accountMenuOpen = false;

    currentPath = '/ujjayini/';

    firstName = '';
    lastName = '';
    cartCount = 0;

    _listenersAttached = false;
    _infoRequest = 0;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        this.currentPath = this.normalizePath(
            window.location.pathname || '/ujjayini/'
        );

        this.attachListeners();

        this.refreshHeaderInfo();
    }


    disconnectedCallback() {

        this.detachListeners();

        // Never leave the page scroll-locked.
        this.setBodyScrollLock(false);
    }


    attachListeners() {

        if (this._listenersAttached) {
            return;
        }

        document.addEventListener('click', this.handleDocumentClick);
        window.addEventListener('keydown', this.handleKeydown);
        window.addEventListener('resize', this.handleResize);
        window.addEventListener('pageshow', this.handlePageShow);

        this._listenersAttached = true;
    }


    detachListeners() {

        if (!this._listenersAttached) {
            return;
        }

        document.removeEventListener('click', this.handleDocumentClick);
        window.removeEventListener('keydown', this.handleKeydown);
        window.removeEventListener('resize', this.handleResize);
        window.removeEventListener('pageshow', this.handlePageShow);

        this._listenersAttached = false;
    }


    // =========================================================
    // ROUTE SYNC
    // =========================================================

    @wire(CurrentPageReference)
    handlePageReference(pageReference) {

        if (!pageReference) {
            return;
        }

        this.currentPath = this.normalizePath(
            window.location.pathname || '/ujjayini/'
        );

        this.closeAllMenus();

        // Cart may have changed on the page we came from.
        this.refreshHeaderInfo();
    }


    // =========================================================
    // GLOBAL EVENT HANDLERS (arrow functions keep "this")
    // =========================================================

    handleDocumentClick = event => {

        if (!this.accountMenuOpen) {
            return;
        }

        const path =
            typeof event.composedPath === 'function'
                ? event.composedPath()
                : [];

        if (!path.includes(this.template.host)) {
            this.accountMenuOpen = false;
        }
    };


    handleKeydown = event => {

        if (event.key === 'Escape') {
            this.closeAllMenus();
        }
    };


    handleResize = () => {

        if (this.menuOpen && window.innerWidth > MOBILE_BREAKPOINT) {
            this.closeAllMenus();
        }
    };


    handlePageShow = event => {

        // Coming back with the browser Back button.
        if (event.persisted) {
            this.closeAllMenus();
            this.refreshHeaderInfo();
        }
    };


    // =========================================================
    // DATA
    // =========================================================

    get isLoggedIn() {
        return !isGuestUser;
    }


    async refreshHeaderInfo() {

        if (isGuestUser) {
            return;
        }

        // Ignore slower, older responses.
        const request = ++this._infoRequest;

        try {

            const info = await getHeaderInfo();

            if (request !== this._infoRequest || !info) {
                return;
            }

            this.firstName = info.firstName || '';
            this.lastName = info.lastName || '';
            this.cartCount = info.cartCount || 0;

        } catch (error) {

            // The header must never break the page.
        }
    }


    get initials() {

        const letters =
            (this.firstName ? this.firstName.charAt(0) : '') +
            (this.lastName ? this.lastName.charAt(0) : '');

        return (letters || 'U').toUpperCase();
    }

    get displayName() {
        return [this.firstName, this.lastName].filter(part => part).join(' ');
    }

    get hasCartItems() {
        return this.cartCount > 0;
    }

    get cartBadge() {
        return this.cartCount > 9 ? '9+' : String(this.cartCount);
    }

    get cartLabel() {
        return this.hasCartItems
            ? 'Cart, ' + this.cartCount + ' items'
            : 'Cart';
    }


    // =========================================================
    // MENUS
    // =========================================================

    toggleMenu() {

        this.menuOpen = !this.menuOpen;
        this.accountMenuOpen = false;

        this.setBodyScrollLock(this.menuOpen);
    }

    closeMenu() {
        this.closeAllMenus();
    }

    toggleAccountMenu(event) {

        event.stopPropagation();

        this.accountMenuOpen = !this.accountMenuOpen;
    }

    closeAllMenus() {

        this.menuOpen = false;
        this.accountMenuOpen = false;

        this.setBodyScrollLock(false);
    }

    setBodyScrollLock(locked) {

        try {
            document.body.style.overflow = locked ? 'hidden' : '';
        } catch (error) {
            // Not critical.
        }
    }

    get menuExpanded() {
        return this.menuOpen ? 'true' : 'false';
    }

    get accountExpanded() {
        return this.accountMenuOpen ? 'true' : 'false';
    }

    get headerClass() {
        return this.menuOpen
            ? 'site-header menu-open'
            : 'site-header';
    }

    get menuButtonClass() {
        return this.menuOpen
            ? 'menu-button is-open'
            : 'menu-button';
    }

    get accountButtonClass() {

        const active =
            this.accountMenuOpen ||
            this.isCurrentPage('/ujjayini/my-account');

        return active
            ? 'account-button is-active'
            : 'account-button';
    }


    // =========================================================
    // SIGN OUT
    // =========================================================

    handleSignOut() {

        this.closeAllMenus();

        const prefix = (basePath || '/ujjayini').replace(/\/s$/i, '');

        window.location.href =
            prefix +
            '/secur/logout.jsp?retUrl=' +
            encodeURIComponent(prefix + '/');
    }


    // =========================================================
    // ACTIVE CLASSES
    // =========================================================

    get homeNavClass() { return this.navClass('/ujjayini/'); }
    get collectionsNavClass() { return this.navClass('/ujjayini/collections'); }
    get watchesNavClass() { return this.navClass('/ujjayini/watches'); }
    get aboutNavClass() { return this.navClass('/ujjayini/about-us'); }
    get serviceNavClass() { return this.navClass('/ujjayini/service'); }

    get wishlistIconClass() { return this.iconClass('/ujjayini/wishlist'); }
    get cartIconClass() { return this.iconClass('/ujjayini/cart'); }

    get homeMobileClass() { return this.mobileClass('/ujjayini/'); }
    get collectionsMobileClass() { return this.mobileClass('/ujjayini/collections'); }
    get watchesMobileClass() { return this.mobileClass('/ujjayini/watches'); }
    get aboutMobileClass() { return this.mobileClass('/ujjayini/about-us'); }
    get serviceMobileClass() { return this.mobileClass('/ujjayini/service'); }
    get wishlistMobileClass() { return this.mobileClass('/ujjayini/wishlist'); }
    get cartMobileClass() { return this.mobileClass('/ujjayini/cart'); }
    get accountMobileClass() { return this.mobileClass('/ujjayini/my-account'); }
    get ordersMobileClass() { return this.mobileClass('/ujjayini/order-history'); }

    navClass(path) {
        return this.isCurrentPage(path) ? 'nav-link active' : 'nav-link';
    }

    iconClass(path) {
        return this.isCurrentPage(path) ? 'icon-link active' : 'icon-link';
    }

    mobileClass(path) {
        return this.isCurrentPage(path) ? 'mobile-link active' : 'mobile-link';
    }


    // =========================================================
    // PATH HELPERS
    // =========================================================

    isCurrentPage(pagePath) {

        const current = this.normalizePath(this.currentPath);
        const target = this.normalizePath(pagePath);

        // HOME is active only on the home page itself.
        if (target === '/ujjayini') {
            return current === '/ujjayini';
        }

        return current === target || current.startsWith(target + '/');
    }

    normalizePath(path) {

        if (!path) {
            return '/';
        }

        let normalized = path.split('?')[0].split('#')[0];

        if (normalized.length > 1 && normalized.endsWith('/')) {
            normalized = normalized.slice(0, -1);
        }

        return normalized;
    }
}