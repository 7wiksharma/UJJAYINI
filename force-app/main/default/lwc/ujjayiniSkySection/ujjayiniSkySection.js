import { LightningElement } from 'lwc';

export default class UjjayiniSkySection extends LightningElement {

    _scrollHandler;
    _rafId;
    _ticking = false;


    connectedCallback() {

        this._scrollHandler =
            this.handleScroll.bind(this);

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

            window.cancelAnimationFrame(
                this._rafId
            );

        }

    }


    handleScroll() {

        if (this._ticking) {

            return;

        }

        this._ticking = true;

        this._rafId =
            window.requestAnimationFrame(() => {

                this.updateParallax();

                this._ticking = false;

            });

    }


    updateParallax() {

        const section =
            this.template.querySelector(
                '.sky-section'
            );

        if (!section) {

            return;

        }


        const rect =
            section.getBoundingClientRect();


        const viewportHeight =
            window.innerHeight || 1;


        /*
         * Section progress
         *
         * 0   = entering viewport
         * 0.5 = centered
         * 1   = leaving viewport
         */

        const progress =
            (
                viewportHeight - rect.top
            ) /
            (
                viewportHeight +
                rect.height
            );


        const clampedProgress =
            Math.max(
                0,
                Math.min(
                    1,
                    progress
                )
            );


        /*
         * ------------------------------------------------------
         * EDITORIAL PARALLAX
         * ------------------------------------------------------
         */

        const centered =
            clampedProgress - 0.5;


        const contentY =
            centered * -30;


        const orbitY =
            centered * 55;


        const starsY =
            centered * 34;


        const axisY =
            centered * 18;


        const backgroundY =
            centered * -18;


        const statementY =
            centered * 20;


        /*
         * Atmospheric scale
         */

        const atmosphereScale =
            1 +
            (
                Math.abs(centered) *
                0.045
            );


        const atmosphereOpacity =
            0.86 +
            (
                1 -
                Math.abs(centered) * 2
            ) * 0.14;


        /*
         * Celestial system rotation.
         *
         * Very subtle intentionally.
         */

        const celestialRotation =
            centered * -7;


        /*
         * Individual orbital points.
         */

        const pointOneY =
            centered * -42;


        const pointTwoY =
            centered * 28;


        const pointThreeY =
            centered * -20;


        /*
         * ------------------------------------------------------
         * APPLY CSS VARIABLES
         * ------------------------------------------------------
         */

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
            '--background-y',
            `${backgroundY}px`
        );


        section.style.setProperty(
            '--statement-y',
            `${statementY}px`
        );


        section.style.setProperty(
            '--atmosphere-scale',
            atmosphereScale
        );


        section.style.setProperty(
            '--atmosphere-opacity',
            atmosphereOpacity
        );


        section.style.setProperty(
            '--celestial-rotation',
            `${celestialRotation}deg`
        );


        section.style.setProperty(
            '--point-one-y',
            `${pointOneY}px`
        );


        section.style.setProperty(
            '--point-two-y',
            `${pointTwoY}px`
        );


        section.style.setProperty(
            '--point-three-y',
            `${pointThreeY}px`
        );

    }

}