import { LightningElement } from 'lwc';

export default class UjjayiniUnseenPrecision extends LightningElement {

    nakshatraDots = [];
    nakshatraTicks = [];
    rashiTicks = [];

    nakshatraCount = 0;
    rashiCount = 0;
    ghatikaCount = 0;

    observer;
    animationFrame;

    connectedCallback() {
        this.buildNakshatraDots();
        this.buildNakshatraTicks();
        this.buildRashiTicks();
    }

    renderedCallback() {
        if (this.observer) {
            return;
        }

        const section = this.template.querySelector(
            '.precision-section'
        );

        if (!section) {
            return;
        }

        this.observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {

                    if (entry.isIntersecting) {

                        this.startCounters();

                        this.observer.disconnect();
                        this.observer = null;

                    }

                });
            },
            {
                threshold: 0.28
            }
        );

        this.observer.observe(section);
    }


    /*
     * =========================================================
     * 27 NAKṢATRA DOTS
     * =========================================================
     */

    buildNakshatraDots() {

        const dots = [];

        for (let i = 0; i < 27; i++) {

            const angle = (360 / 27) * i;

            dots.push({
                id: `nakshatra-dot-${i}`,
                style: `
                    transform:
                    rotate(${angle}deg)
                    translateY(-${this.getOuterRingRadius()}px);
                `
            });

        }

        this.nakshatraDots = dots;
    }


    /*
     * =========================================================
     * 27 NAKṢATRA TICKS
     * =========================================================
     */

    buildNakshatraTicks() {

        const ticks = [];

        for (let i = 0; i < 27; i++) {

            const angle = (360 / 27) * i;

            ticks.push({
                id: `nakshatra-tick-${i}`,
                style: `
                    transform:
                    rotate(${angle}deg)
                    translateY(-${this.getNakshatraTickRadius()}px);
                `
            });

        }

        this.nakshatraTicks = ticks;
    }


    /*
     * =========================================================
     * 12 RĀŚI TICKS
     * =========================================================
     */

    buildRashiTicks() {

        const ticks = [];

        for (let i = 0; i < 12; i++) {

            const angle = (360 / 12) * i;

            ticks.push({
                id: `rashi-tick-${i}`,
                style: `
                    transform:
                    rotate(${angle}deg)
                    translateY(-${this.getRashiTickRadius()}px);
                `
            });

        }

        this.rashiTicks = ticks;
    }


    /*
     * =========================================================
     * RING DIMENSIONS
     * =========================================================
     */

    getOuterRingRadius() {
        return 220;
    }

    getNakshatraTickRadius() {
        return 198;
    }

    getRashiTickRadius() {
        return 176;
    }


    /*
     * =========================================================
     * COUNTERS
     * =========================================================
     */

    startCounters() {

        this.animateCounter(
            'nakshatraCount',
            27,
            1300
        );

        this.animateCounter(
            'rashiCount',
            12,
            1000
        );

        this.animateCounter(
            'ghatikaCount',
            60,
            1600
        );
    }


    animateCounter(property, target, duration) {

        const startTime = performance.now();

        const update = (currentTime) => {

            const elapsed = currentTime - startTime;

            const progress = Math.min(
                elapsed / duration,
                1
            );

            /*
             * Ease-out curve.
             * Starts quickly and settles smoothly.
             */
            const eased =
                1 - Math.pow(1 - progress, 3);

            this[property] =
                Math.round(target * eased);

            if (progress < 1) {

                this.animationFrame =
                    requestAnimationFrame(update);

            } else {

                this[property] = target;

            }
        };

        this.animationFrame =
            requestAnimationFrame(update);
    }


    disconnectedCallback() {

        if (this.observer) {
            this.observer.disconnect();
            this.observer = null;
        }

        if (this.animationFrame) {
            cancelAnimationFrame(
                this.animationFrame
            );
        }
    }
}