import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getProducts from '@salesforce/apex/UJJAYINIProductCatalogController.getProducts';
import addToCart from '@salesforce/apex/UJJAYINICartController.addToCart';

import getWishlistItems from '@salesforce/apex/UJJAYINIWishlistController.getWishlistItems';
import addToWishlist from '@salesforce/apex/UJJAYINIWishlistController.addToWishlist';
import removeFromWishlist from '@salesforce/apex/UJJAYINIWishlistController.removeFromWishlist';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class UjjayiniProductCatalog extends NavigationMixin(LightningElement) {

    products = [];
    error;
    isLoading = true;
    retryCount = 0;

    connectedCallback() {
        this.loadProducts();
    }

    async loadProducts() {

        this.isLoading = true;
        this.error = undefined;

        try {

            const [productData, wishlistData] =
                await Promise.all([
                    getProducts(),
                    getWishlistItems()
                ]);

            const wishlistedProductIds =
                new Set(
                    (wishlistData || []).map(
                        item => item.productId
                    )
                );

            this.products =
                (productData || []).map(product => ({
                    ...product,
                    isAddingToCart: false,
                    isAddingToWishlist: false,
                    isWishlisted:
                        wishlistedProductIds.has(
                            product.productId
                        )
                }));

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


    async handleAddToCart(event) {

        const productId =
            event.currentTarget.dataset.productId;

        this.products = this.products.map(product => {

            if (product.productId === productId) {

                return {
                    ...product,
                    isAddingToCart: true
                };
            }

            return product;
        });

        try {

            await addToCart({
                productId: productId,
                quantity: 1
            });

            this.showToast(
                'Added to Cart',
                'Watch added to your cart successfully.',
                'success'
            );

        } catch (error) {

            this.showToast(
                'Unable to Add to Cart',
                this.getErrorMessage(error),
                'error'
            );

        } finally {

            this.products = this.products.map(product => {

                if (product.productId === productId) {

                    return {
                        ...product,
                        isAddingToCart: false
                    };
                }

                return product;
            });
        }
    }


    async handleWishlist(event) {

        const productId =
            event.currentTarget.dataset.productId;

        const product =
            this.products.find(
                item => item.productId === productId
            );

        if (!product) {
            return;
        }

        this.products = this.products.map(item => {

            if (item.productId === productId) {

                return {
                    ...item,
                    isAddingToWishlist: true
                };
            }

            return item;
        });

        try {

            if (product.isWishlisted) {

                await removeFromWishlist({
                    productId: productId
                });

                this.products =
                    this.products.map(item => {

                        if (item.productId === productId) {

                            return {
                                ...item,
                                isWishlisted: false,
                                isAddingToWishlist: false
                            };
                        }

                        return item;
                    });

                this.showToast(
                    'Removed from Wishlist',
                    'Watch removed from your wishlist.',
                    'success'
                );

            } else {

                await addToWishlist({
                    productId: productId
                });

                this.products =
                    this.products.map(item => {

                        if (item.productId === productId) {

                            return {
                                ...item,
                                isWishlisted: true,
                                isAddingToWishlist: false
                            };
                        }

                        return item;
                    });

                this.showToast(
                    'Added to Wishlist',
                    'Watch added to your wishlist.',
                    'success'
                );
            }

        } catch (error) {

            this.products =
                this.products.map(item => {

                    if (item.productId === productId) {

                        return {
                            ...item,
                            isAddingToWishlist: false
                        };
                    }

                    return item;
                });

            this.showToast(
                'Wishlist Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

handleProductClick(event) {

    const productId =
        event.currentTarget.dataset.productId;

    if (!productId) {
        return;
    }

    this[NavigationMixin.Navigate]({
        type: 'comm__namedPage',
        attributes: {
            name: 'Product_Detail__c'
        },
        state: {
            productId: productId
        }
    });
}
    get hasProducts() {
        return this.products.length > 0;
    }


    get hasError() {
        return this.error != null &&
               this.products.length === 0;
    }


    getErrorMessage(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Something went wrong.';
    }


    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}