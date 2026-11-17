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
// COLLECTION CONFIG
// =========================================================

const COLLECTIONS = [
    {
        key: 'indranila',
        filter: 'INDRANĪLA',
        number: '01',
        eyebrow: 'THE CELESTIAL COLLECTION',
        title: 'Indranīla',
        tagline: 'The depth of midnight. The brilliance of sapphire.',
        signature: 'SAPPHIRE · MIDNIGHT',
        className: 'collection-block indranila-section'
    },

    {
        key: 'hiranya',
        filter: 'HIRANYA',
        number: '02',
        eyebrow: 'THE SOVEREIGN COLLECTION',
        title: 'Hiranya',
        tagline: 'Gold forged into memory. Radiance made eternal.',
        signature: 'GOLD · DAWN',
        className: 'collection-block hiranya-section'
    },

    {
        key: 'ayas',
        filter: 'AYAS',
        number: '03',
        eyebrow: 'THE ETERNAL COLLECTION',
        title: 'Ayas',
        tagline: 'Steel shaped by precision. Permanence in every detail.',
        signature: 'STEEL · ETERNAL',
        className: 'collection-block ayas-section'
    }
];


const FILTERS = [
    {
        value: 'ALL',
        label: 'ALL'
    },

    {
        value: 'INDRANĪLA',
        label: 'INDRANĪLA'
    },

    {
        value: 'HIRANYA',
        label: 'HIRANYA'
    },

    {
        value: 'AYAS',
        label: 'AYAS'
    }
];


export default class UjjayiniProductCatalog
    extends NavigationMixin(LightningElement) {


    // =========================================================
    // STATE
    // =========================================================

    products = [];

    error;

    isLoading = true;

    retryCount = 0;

    activeCollection = 'ALL';

    sortBy = 'featured';

    videoReady = false;

    _videoInitialized = false;


    // =========================================================
    // UJJAYINI NOTIFICATION STATE
    // =========================================================

    showNotification = false;

    notificationType = '';

    notificationTitle = '';

    notificationMessage = '';

    notificationTimer;


    // =========================================================
    // GUEST CART MODAL
    // =========================================================

    showGuestCartModal = false;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {
        this.loadProducts();
    }


    disconnectedCallback() {

        if (this.notificationTimer) {
            clearTimeout(this.notificationTimer);
        }

    }


    renderedCallback() {

        if (this._videoInitialized) {
            return;
        }

        const video =
            this.template.querySelector('video');

        if (!video) {
            return;
        }

        this._videoInitialized = true;

        video.muted = true;
        video.defaultMuted = true;

        const reduceMotion =
            window.matchMedia &&
            window.matchMedia(
                '(prefers-reduced-motion: reduce)'
            ).matches;

        if (reduceMotion) {
            this.videoReady = true;
            return;
        }

        const playPromise = video.play();

        if (
            playPromise &&
            playPromise.catch
        ) {

            playPromise.catch(() => {
                // Browser blocked autoplay.
            });

        }

    }


    // =========================================================
    // VIDEO
    // =========================================================

    get pantherVideoUrl() {
        return pantherVideo;
    }


    handleVideoReady() {
        this.videoReady = true;
    }


    get videoClass() {

        return this.videoReady
            ? 'panther-video is-ready'
            : 'panther-video';

    }


    // =========================================================
    // LOAD PRODUCTS
    // =========================================================

    async loadProducts() {

        this.isLoading = true;

        this.error = undefined;

        try {

            const [
                productData,
                wishlistData
            ] = await Promise.all([

                getProducts(),

                getWishlistItems()

            ]);


            const wishlistedProductIds =
                new Set(
                    (wishlistData || [])
                        .map(
                            item =>
                                item.productId
                        )
                );


            this.products =
                (productData || []).map(
                    (product, index) => ({

                        ...product,

                        isAddingToCart: false,

                        isAddingToWishlist: false,

                        isWishlisted:
                            wishlistedProductIds.has(
                                product.productId
                            ),

                        displayIndex:
                            String(index + 1)
                                .padStart(2, '0')

                    })
                );


            this.error = undefined;

            this.isLoading = false;

            this.retryCount = 0;

        } catch (error) {

            this.products = [];

            this.error = error;

            this.isLoading = false;


            if (this.retryCount < 3) {

                this.retryCount++;

                setTimeout(() => {

                    this.loadProducts();

                }, 1000);

            }

        }

    }


    // =========================================================
    // COLLECTION HELPERS
    // =========================================================

    normalizeCollection(name) {

        if (!name) {
            return '';
        }

        return name
            .toLowerCase()
            .replace(/ī/g, 'i')
            .trim();

    }


    isCollection(product, collection) {

        return (
            this.normalizeCollection(
                product.collectionName
            ) ===
            this.normalizeCollection(
                collection
            )
        );

    }


    // =========================================================
    // FILTERED + SORTED PRODUCTS
    // =========================================================

    get filteredProducts() {

        let result = [...this.products];


        if (
            this.activeCollection !== 'ALL'
        ) {

            result =
                result.filter(
                    product =>
                        this.isCollection(
                            product,
                            this.activeCollection
                        )
                );

        }


        result.sort((a, b) => {

            if (
                this.sortBy === 'price-low'
            ) {

                return (
                    (a.price || 0) -
                    (b.price || 0)
                );

            }


            if (
                this.sortBy === 'price-high'
            ) {

                return (
                    (b.price || 0) -
                    (a.price || 0)
                );

            }


            if (
                this.sortBy === 'name'
            ) {

                return (
                    (a.productName || '')
                        .localeCompare(
                            b.productName || ''
                        )
                );

            }


            return 0;

        });


        return result;

    }


    // =========================================================
    // COLLECTION SECTIONS
    // =========================================================

    get collectionSections() {

        const filtered =
            this.filteredProducts;


        return COLLECTIONS

            .filter(collection =>

                this.activeCollection === 'ALL' ||

                this.normalizeCollection(
                    this.activeCollection
                ) ===
                this.normalizeCollection(
                    collection.filter
                )

            )

            .map(collection => ({

                ...collection,

                products:

                    filtered

                        .filter(product =>
                            this.isCollection(
                                product,
                                collection.filter
                            )
                        )

                        .map(product =>
                            this.decorateProduct(
                                product
                            )
                        )

            }))

            .filter(section =>
                section.products.length > 0
            );

    }


    decorateProduct(product) {

        return {

            ...product,

            formattedPrice:
                product.price
                    ? Number(
                        product.price
                    ).toLocaleString('en-IN')
                    : '',

            wishlistIcon:
                product.isWishlisted
                    ? '♥'
                    : '♡',

            wishlistTitle:
                product.isWishlisted
                    ? 'Remove from Wishlist'
                    : 'Add to Wishlist',

            wishlistClass:
                product.isWishlisted
                    ? 'wishlist-button is-active'
                    : 'wishlist-button',

            cartLabel:
                product.isAddingToCart
                    ? 'ADDING TO CART'
                    : 'ADD TO CART'

        };

    }


    get totalCount() {

        return String(
            this.products.length
        ).padStart(2, '0');

    }


    // =========================================================
    // FILTER BUTTONS
    // =========================================================

    get filterOptions() {

        return FILTERS.map(filter => ({

            ...filter,

            className:
                this.activeCollection ===
                filter.value

                    ? 'filter-button active'

                    : 'filter-button'

        }));

    }


    // =========================================================
    // FILTER
    // =========================================================

    handleCollectionFilter(event) {

        this.activeCollection =
            event.currentTarget.dataset.filter;

    }


    handleSortChange(event) {

        this.sortBy =
            event.target.value;

    }


    resetFilters() {

        this.activeCollection = 'ALL';

        this.sortBy = 'featured';

    }


    // =========================================================
    // HERO CTA
    // =========================================================

    handleScrollToCatalog() {

        const target =
            this.template.querySelector(
                '.catalog-workspace'
            );


        if (target) {

            target.scrollIntoView({

                behavior: 'smooth',

                block: 'start'

            });

        }

    }


    // =========================================================
    // PAGE STATES
    // =========================================================

    get hasProducts() {

        return this.products.length > 0;

    }


    get showEmpty() {

        return (

            !this.isLoading &&

            !this.hasError &&

            this.filteredProducts.length === 0

        );

    }


    get hasError() {

        return (

            this.error != null &&

            this.products.length === 0

        );

    }


    get errorMessage() {

        return this.getErrorMessage(
            this.error
        );

    }


    // =========================================================
    // ADD TO CART
    // =========================================================

    async handleAddToCart(event) {

        event.stopPropagation();


        const productId =
            event.currentTarget.dataset.productId;


        if (!productId) {
            return;
        }


        // =====================================================
        // GUEST USER
        // =====================================================

        if (isGuestUser) {

            this.showGuestCartModal = true;

            return;

        }


        // =====================================================
        // AUTHENTICATED USER
        // =====================================================

        this.updateProduct(

            productId,

            {
                isAddingToCart: true
            }

        );


        try {

            await addToCart({

                productId,

                quantity: 1

            });


            // -----------------------------------------------
            // SUCCESS POPUP
            // -----------------------------------------------

            this.showNotificationPopup(

                'success',

                'ADDED TO CART',

                'The timepiece has been added to your collection.'

            );


        } catch (error) {

            // -----------------------------------------------
            // ERROR POPUP
            // -----------------------------------------------

            this.showNotificationPopup(

                'error',

                'UNABLE TO ADD',

                this.getErrorMessage(error)

            );

        } finally {

            this.updateProduct(

                productId,

                {
                    isAddingToCart: false
                }

            );

        }

    }


    // =========================================================
    // UJJAYINI CUSTOM NOTIFICATION
    // =========================================================

    showNotificationPopup(
        type,
        title,
        message
    ) {

        if (this.notificationTimer) {

            clearTimeout(
                this.notificationTimer
            );

        }


        this.notificationType = type;

        this.notificationTitle = title;

        this.notificationMessage = message;

        this.showNotification = true;


        this.notificationTimer =
            setTimeout(() => {

                this.showNotification = false;

            }, 4000);

    }


    closeNotification() {

        this.showNotification = false;


        if (this.notificationTimer) {

            clearTimeout(
                this.notificationTimer
            );

            this.notificationTimer = null;

        }

    }


    get notificationClass() {

        return this.notificationType === 'error'

            ? 'ujjayini-notification error'

            : 'ujjayini-notification success';

    }


    // =========================================================
    // GUEST CART MODAL
    // =========================================================

    closeGuestCartModal() {

        this.showGuestCartModal = false;

    }


    stopModalPropagation(event) {

        event.stopPropagation();

    }


    handleGuestLogin() {

        const startUrl =
            window.location.pathname +
            window.location.search;


        window.location.href =
            '/ujjayini/login?startURL=' +
            encodeURIComponent(
                startUrl
            );

    }


    handleGuestSignup() {

        window.location.href =
            '/ujjayini/self-register';

    }


    // =========================================================
    // WISHLIST
    // =========================================================

    async handleWishlist(event) {

        event.stopPropagation();


        const productId =
            event.currentTarget.dataset.productId;


        const product =
            this.products.find(
                item =>
                    item.productId ===
                    productId
            );


        if (!product) {
            return;
        }


        this.updateProduct(

            productId,

            {
                isAddingToWishlist: true
            }

        );


        try {

            if (product.isWishlisted) {

                await removeFromWishlist({

                    productId

                });


                this.updateProduct(

                    productId,

                    {
                        isWishlisted: false,

                        isAddingToWishlist:
                            false
                    }

                );


                this.showNotificationPopup(

                    'success',

                    'REMOVED FROM WISHLIST',

                    'The timepiece has been removed from your wishlist.'

                );

            } else {

                await addToWishlist({

                    productId

                });


                this.updateProduct(

                    productId,

                    {
                        isWishlisted: true,

                        isAddingToWishlist:
                            false
                    }

                );


                this.showNotificationPopup(

                    'success',

                    'ADDED TO WISHLIST',

                    'The timepiece has been added to your wishlist.'

                );

            }

        } catch (error) {

            this.updateProduct(

                productId,

                {
                    isAddingToWishlist:
                        false
                }

            );


            this.showNotificationPopup(

                'error',

                'WISHLIST ERROR',

                this.getErrorMessage(error)

            );

        }

    }


    // =========================================================
    // PRODUCT UPDATE
    // =========================================================

    updateProduct(
        productId,
        changes
    ) {

        this.products =
            this.products.map(product =>

                product.productId === productId

                    ? {
                        ...product,
                        ...changes
                    }

                    : product

            );

    }


    // =========================================================
    // PRODUCT DETAIL
    // =========================================================

    handleProductClick(event) {

        event.stopPropagation();


        const productId =
            event.currentTarget.dataset.productId;


        if (!productId) {
            return;
        }


        this[
            NavigationMixin.Navigate
        ]({

            type: 'comm__namedPage',

            attributes: {

                name: 'Product_Detail__c'

            },

            state: {

                productId

            }

        });

    }


    // =========================================================
    // ERROR
    // =========================================================

    getErrorMessage(error) {

        if (
            error?.body?.message
        ) {

            return error.body.message;

        }


        if (
            error?.message
        ) {

            return error.message;

        }


        return 'Something went wrong.';

    }

}