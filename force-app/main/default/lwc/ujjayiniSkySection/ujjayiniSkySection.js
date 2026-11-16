import { LightningElement } from 'lwc';

export default class UjjayiniSkySection extends LightningElement {
    _scrollHandler;
    _rafId;
    _ticking = false;

    connectedCallback() {
        this._scrollHandler = this.handleScroll.bind(this);

        window.addEventListener(
            'scroll',
            this._scrollHandler,
            { passive: true }
        );
    }

    renderedCallback() {
        this.updateParallax();
    }

    disconnectedCallback() {
        window.removeEventListener(
            'scroll',
            this._scrollHandler
        );

        if (this._rafId) {
            window.cancelAnimationFrame(this._rafId);
        }
    }

    handleScroll() {
        if (this._ticking) {
            return;
        }

        this._ticking = true;

        this._rafId = window.requestAnimationFrame(() => {
            this.updateParallax();
            this._ticking = false;
        });
    }

    updateParallax() {
        const section = this.template.querySelector('.sky-section');

        if (!section) {
            return;
        }

        const rect = section.getBoundingClientRect();
        const viewportHeight = window.innerHeight || 1;

        /*
         * Progress:
         * 0   = section entering viewport
         * 0.5 = section centered
         * 1   = section leaving viewport
         */
        const progress =
            (viewportHeight - rect.top) /
            (viewportHeight + rect.height);

        const clampedProgress = Math.max(
            0,
            Math.min(1, progress)
        );

        /*
         * Keep movement extremely subtle.
         * This is a luxury editorial section,
         * so nothing should feel like a normal website animation.
         */

        const contentY =
            (clampedProgress - 0.5) * -34;

        const orbitY =
            (clampedProgress - 0.5) * 48;

        const starsY =
            (clampedProgress - 0.5) * 28;

        const axisY =
            (clampedProgress - 0.5) * 16;

        const dotOneY =
            (clampedProgress - 0.5) * -38;

        const dotTwoY =
            (clampedProgress - 0.5) * 26;

        const dotThreeY =
            (clampedProgress - 0.5) * -20;

        const atmosphereScale =
            1 + (
                Math.abs(clampedProgress - 0.5) * 0.035
            );

        const atmosphereOpacity =
            0.88 +
            (
                1 -
                Math.abs(clampedProgress - 0.5) * 2
            ) * 0.12;

        section.style.setProperty(
            '--content-y',
            `${contentY}px`
        );

        section.style.setProperty(
            '--orbit-y',
            `${orbitY}px`
        );

        section.style.setProperty(
            '--stars-y',
            `${starsY}px`
        );

        section.style.setProperty(
            '--axis-y',
            `${axisY}px`
        );

        section.style.setProperty(
            '--dot-one-y',
            `${dotOneY}px`
        );

        section.style.setProperty(
            '--dot-two-y',
            `${dotTwoY}px`
        );

        section.style.setProperty(
            '--dot-three-y',
            `${dotThreeY}px`
        );

        section.style.setProperty(
            '--atmosphere-scale',
            atmosphereScale
        );

        section.style.setProperty(
            '--atmosphere-opacity',
            atmosphereOpacity
        );
    }
}