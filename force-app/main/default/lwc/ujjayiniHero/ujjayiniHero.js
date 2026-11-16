import { LightningElement } from 'lwc';

export default class UjjayiniHero extends LightningElement {

    canvas;
    ctx;

    animationFrame;

    resizeObserver;

    scrollHandler;

    currentRotation = 0;
    targetRotation = 0;

    lastScrollY = 0;

    ghatika = '00';

    connectedCallback() {

        this.scrollHandler = this.handleScroll.bind(this);

        window.addEventListener(
            'scroll',
            this.scrollHandler,
            { passive: true }
        );

        this.lastScrollY = window.scrollY || 0;

        this.updateGhatika();

    }


    renderedCallback() {

        if (this.canvas) {
            return;
        }

        this.canvas =
            this.template.querySelector(
                '.watch-canvas'
            );

        if (!this.canvas) {
            return;
        }

        this.ctx =
            this.canvas.getContext('2d');

        this.resizeCanvas();

        this.resizeObserver =
            new ResizeObserver(() => {
                this.resizeCanvas();
            });

        const stage =
            this.template.querySelector(
                '.watch-stage'
            );

        if (stage) {
            this.resizeObserver.observe(stage);
        }

        this.startAnimation();

    }


    disconnectedCallback() {

        window.removeEventListener(
            'scroll',
            this.scrollHandler
        );

        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
        }

        if (this.animationFrame) {
            cancelAnimationFrame(
                this.animationFrame
            );
        }

    }


    /* =====================================================
       CANVAS SIZE
    ===================================================== */

    resizeCanvas() {

        if (!this.canvas) {
            return;
        }

        const rect =
            this.canvas.getBoundingClientRect();

        const dpr =
            Math.min(
                window.devicePixelRatio || 1,
                2
            );

        this.canvas.width =
            Math.max(
                1,
                Math.floor(
                    rect.width * dpr
                )
            );

        this.canvas.height =
            Math.max(
                1,
                Math.floor(
                    rect.height * dpr
                )
            );

        this.ctx.setTransform(
            dpr,
            0,
            0,
            dpr,
            0,
            0
        );

    }


    /* =====================================================
       SCROLL
    ===================================================== */

    handleScroll() {

        const currentY =
            window.scrollY || 0;

        const delta =
            currentY - this.lastScrollY;

        /*
         * Scroll controls the horizontal
         * rotation of the watch.
         *
         * Small delta = elegant movement.
         */

        this.targetRotation +=
            delta * 0.0032;

        /*
         * Keep rotation under control.
         */

        const maxRotation =
            Math.PI * 0.72;

        this.targetRotation =
            Math.max(
                -maxRotation,
                Math.min(
                    maxRotation,
                    this.targetRotation
                )
            );

        this.lastScrollY =
            currentY;

        this.updateGhatika();

    }


    /* =====================================================
       GHATIKA
    ===================================================== */

    updateGhatika() {

        /*
         * 60 ghaṭikā = traditional Indian
         * division of a full day.
         *
         * We use the current day fraction
         * purely as visual HUD data.
         */

        const now =
            new Date();

        const seconds =
            now.getHours() * 3600 +
            now.getMinutes() * 60 +
            now.getSeconds();

        const daySeconds =
            24 * 60 * 60;

        const value =
            Math.floor(
                (seconds / daySeconds) * 60
            );

        this.ghatika =
            String(
                value % 60
            ).padStart(
                2,
                '0'
            );

    }


    /* =====================================================
       ANIMATION LOOP
    ===================================================== */

    startAnimation() {

        const animate = () => {

            /*
             * Smooth interpolation.
             */

            this.currentRotation +=
                (
                    this.targetRotation -
                    this.currentRotation
                ) * 0.075;

            this.drawWatch(
                this.currentRotation
            );

            this.animationFrame =
                requestAnimationFrame(
                    animate
                );

        };

        animate();

    }


    /* =====================================================
       MAIN WATCH DRAW
    ===================================================== */

    drawWatch(rotation) {

        if (!this.ctx || !this.canvas) {
            return;
        }

        const rect =
            this.canvas.getBoundingClientRect();

        const width =
            rect.width;

        const height =
            rect.height;

        this.ctx.clearRect(
            0,
            0,
            width,
            height
        );

        /*
         * Watch center.
         *
         * Intentionally placed toward the
         * right side of the hero.
         */

        const centerX =
            width * 0.59;

        const centerY =
            height * 0.50;

        /*
         * Base watch size.
         */

        const baseSize =
            Math.min(
                height * 0.73,
                width * 0.68
            );

        /*
         * Perspective.
         *
         * When rotated toward the side,
         * the visible width decreases.
         */

        const perspective =
            0.42 +
            0.58 *
            Math.abs(
                Math.cos(rotation)
            );

        const watchWidth =
            baseSize *
            perspective;

        const watchHeight =
            baseSize;

        /*
         * Shadow.
         */

        this.drawWatchShadow(
            centerX,
            centerY,
            watchWidth,
            watchHeight
        );

        /*
         * Strap.
         */

        this.drawStrap(
            centerX,
            centerY,
            watchWidth,
            watchHeight,
            rotation
        );

        /*
         * Case.
         */

        this.drawCase(
            centerX,
            centerY,
            watchWidth,
            watchHeight,
            rotation
        );

        /*
         * Crown.
         */

        this.drawCrown(
            centerX,
            centerY,
            watchWidth,
            rotation
        );

        /*
         * Dial.
         */

        this.drawDial(
            centerX,
            centerY,
            watchWidth,
            watchHeight,
            rotation
        );

        /*
         * Hands.
         */

        this.drawHands(
            centerX,
            centerY,
            watchWidth,
            watchHeight,
            rotation
        );

        /*
         * Glass reflection.
         */

        this.drawGlass(
            centerX,
            centerY,
            watchWidth,
            watchHeight,
            rotation
        );

    }


    /* =====================================================
       SHADOW
    ===================================================== */

    drawWatchShadow(
        x,
        y,
        width,
        height
    ) {

        const ctx = this.ctx;

        ctx.save();

        ctx.translate(
            x + 16,
            y + 20
        );

        ctx.scale(
            1,
            0.96
        );

        const gradient =
            ctx.createRadialGradient(
                0,
                0,
                width * 0.18,
                0,
                0,
                width * 0.62
            );

        gradient.addColorStop(
            0,
            'rgba(0,0,0,0.55)'
        );

        gradient.addColorStop(
            0.55,
            'rgba(0,0,0,0.28)'
        );

        gradient.addColorStop(
            1,
            'rgba(0,0,0,0)'
        );

        ctx.fillStyle =
            gradient;

        ctx.beginPath();

        ctx.ellipse(
            0,
            0,
            width * 0.52,
            height * 0.52,
            0,
            0,
            Math.PI * 2
        );

        ctx.fill();

        ctx.restore();

    }


    /* =====================================================
       STRAP
    ===================================================== */

    drawStrap(
        x,
        y,
        width,
        height,
        rotation
    ) {

        const ctx = this.ctx;

        const strapWidth =
            Math.max(
                width * 0.36,
                70
            );

        const strapTop =
            y - height * 0.74;

        const strapBottom =
            y + height * 0.74;

        /*
         * Strap perspective.
         */

        const perspective =
            0.72 +
            0.28 *
            Math.abs(
                Math.cos(rotation)
            );

        ctx.save();

        ctx.translate(x, 0);

        ctx.scale(
            perspective,
            1
        );

        /*
         * Main strap.
         */

        const strapGradient =
            ctx.createLinearGradient(
                0,
                strapTop,
                0,
                strapBottom
            );

        strapGradient.addColorStop(
            0,
            '#171717'
        );

        strapGradient.addColorStop(
            0.45,
            '#2b2925'
        );

        strapGradient.addColorStop(
            0.5,
            '#151515'
        );

        strapGradient.addColorStop(
            1,
            '#080808'
        );

        ctx.fillStyle =
            strapGradient;

        ctx.fillRect(
            -strapWidth / 2,
            strapTop,
            strapWidth,
            strapBottom - strapTop
        );

        /*
         * Central leather highlight.
         */

        const leatherHighlight =
            ctx.createLinearGradient(
                -strapWidth / 2,
                0,
                strapWidth / 2,
                0
            );

        leatherHighlight.addColorStop(
            0,
            'rgba(255,255,255,0)'
        );

        leatherHighlight.addColorStop(
            0.48,
            'rgba(255,255,255,0.025)'
        );

        leatherHighlight.addColorStop(
            0.52,
            'rgba(201,162,77,0.10)'
        );

        leatherHighlight.addColorStop(
            1,
            'rgba(255,255,255,0)'
        );

        ctx.fillStyle =
            leatherHighlight;

        ctx.fillRect(
            -strapWidth / 2,
            strapTop,
            strapWidth,
            strapBottom - strapTop
        );

        /*
         * Strap stitching.
         */

        ctx.strokeStyle =
            'rgba(201,162,77,0.20)';

        ctx.lineWidth = 1;

        ctx.setLineDash([
            5,
            8
        ]);

        ctx.beginPath();

        ctx.moveTo(
            -strapWidth * 0.36,
            strapTop
        );

        ctx.lineTo(
            -strapWidth * 0.36,
            strapBottom
        );

        ctx.moveTo(
            strapWidth * 0.36,
            strapTop
        );

        ctx.lineTo(
            strapWidth * 0.36,
            strapBottom
        );

        ctx.stroke();

        ctx.setLineDash([]);

        ctx.restore();

    }


    /* =====================================================
       CASE
    ===================================================== */

    drawCase(
        x,
        y,
        width,
        height,
        rotation
    ) {

        const ctx = this.ctx;

        const radiusX =
            width * 0.50;

        const radiusY =
            height * 0.50;

        /*
         * Outer black case.
         */

        ctx.save();

        ctx.beginPath();

        ctx.ellipse(
            x,
            y,
            radiusX,
            radiusY,
            0,
            0,
            Math.PI * 2
        );

        const outerGradient =
            ctx.createRadialGradient(
                x - radiusX * 0.35,
                y - radiusY * 0.35,
                radiusX * 0.08,
                x,
                y,
                radiusX
            );

        outerGradient.addColorStop(
            0,
            '#3a3a37'
        );

        outerGradient.addColorStop(
            0.42,
            '#111111'
        );

        outerGradient.addColorStop(
            0.82,
            '#020202'
        );

        outerGradient.addColorStop(
            1,
            '#000000'
        );

        ctx.fillStyle =
            outerGradient;

        ctx.fill();

        /*
         * Outer gold ring.
         */

        ctx.strokeStyle =
            '#8d6a22';

        ctx.lineWidth =
            Math.max(
                5,
                width * 0.018
            );

        ctx.stroke();

        /*
         * Bright gold highlight.
         */

        ctx.beginPath();

        ctx.ellipse(
            x - width * 0.015,
            y - height * 0.015,
            radiusX * 0.955,
            radiusY * 0.955,
            0,
            -Math.PI * 0.92,
            -Math.PI * 0.08
        );

        ctx.strokeStyle =
            'rgba(255,220,130,0.82)';

        ctx.lineWidth =
            Math.max(
                2,
                width * 0.009
            );

        ctx.stroke();

        /*
         * Inner gold bezel.
         */

        ctx.beginPath();

        ctx.ellipse(
            x,
            y,
            radiusX * 0.91,
            radiusY * 0.91,
            0,
            0,
            Math.PI * 2
        );

        const bezelGradient =
            ctx.createLinearGradient(
                x - radiusX,
                y,
                x + radiusX,
                y
            );

        bezelGradient.addColorStop(
            0,
            '#3b280b'
        );

        bezelGradient.addColorStop(
            0.25,
            '#c9a24d'
        );

        bezelGradient.addColorStop(
            0.5,
            '#6d4a13'
        );

        bezelGradient.addColorStop(
            0.75,
            '#d6af58'
        );

        bezelGradient.addColorStop(
            1,
            '#39270d'
        );

        ctx.strokeStyle =
            bezelGradient;

        ctx.lineWidth =
            Math.max(
                3,
                width * 0.012
            );

        ctx.stroke();

        /*
         * Case depth.
         */

        if (Math.abs(rotation) > 0.45) {

            const depth =
                width *
                0.055 *
                Math.sin(
                    Math.abs(rotation)
                );

            ctx.beginPath();

            ctx.ellipse(
                x - depth,
                y,
                radiusX * 1.01,
                radiusY * 1.01,
                0,
                0,
                Math.PI * 2
            );

            ctx.strokeStyle =
                'rgba(0,0,0,0.8)';

            ctx.lineWidth =
                width * 0.035;

            ctx.stroke();

        }

        ctx.restore();

    }


    /* =====================================================
       CROWN
    ===================================================== */

    drawCrown(
        x,
        y,
        width,
        rotation
    ) {

        const ctx = this.ctx;

        /*
         * Crown becomes slightly offset
         * during perspective rotation.
         */

        const side =
            Math.cos(rotation) >= 0
                ? 1
                : -1;

        const crownX =
            x +
            width *
            0.515 *
            side;

        const crownY =
            y +
            4;

        const crownWidth =
            width * 0.085;

        const crownHeight =
            width * 0.14;

        ctx.save();

        /*
         * Crown shadow.
         */

        ctx.fillStyle =
            'rgba(0,0,0,0.7)';

        ctx.beginPath();

        ctx.roundRect(
            crownX -
                crownWidth * 0.52 +
                5,
            crownY -
                crownHeight * 0.5 +
                5,
            crownWidth,
            crownHeight,
            crownWidth * 0.22
        );

        ctx.fill();

        /*
         * Crown body.
         */

        const crownGradient =
            ctx.createLinearGradient(
                crownX -
                    crownWidth / 2,
                0,
                crownX +
                    crownWidth / 2,
                0
            );

        crownGradient.addColorStop(
            0,
            '#5c4012'
        );

        crownGradient.addColorStop(
            0.35,
            '#d5ad55'
        );

        crownGradient.addColorStop(
            0.55,
            '#8c641d'
        );

        crownGradient.addColorStop(
            1,
            '#3c290b'
        );

        ctx.fillStyle =
            crownGradient;

        ctx.beginPath();

        ctx.roundRect(
            crownX -
                crownWidth / 2,
            crownY -
                crownHeight / 2,
            crownWidth,
            crownHeight,
            crownWidth * 0.22
        );

        ctx.fill();

        /*
         * Crown ridges.
         */

        ctx.strokeStyle =
            'rgba(255,220,140,0.28)';

        ctx.lineWidth = 1;

        for (
            let i = -2;
            i <= 2;
            i++
        ) {

            const offset =
                i *
                crownWidth *
                0.13;

            ctx.beginPath();

            ctx.moveTo(
                crownX + offset,
                crownY -
                    crownHeight *
                    0.32
            );

            ctx.lineTo(
                crownX + offset,
                crownY +
                    crownHeight *
                    0.32
            );

            ctx.stroke();

        }

        ctx.restore();

    }


    /* =====================================================
       DIAL
    ===================================================== */

    drawDial(
        x,
        y,
        width,
        height,
        rotation
    ) {

        const ctx = this.ctx;

        const radiusX =
            width * 0.425;

        const radiusY =
            height * 0.425;

        ctx.save();

        /*
         * Dial base.
         */

        const dialGradient =
            ctx.createRadialGradient(
                x - radiusX * 0.30,
                y - radiusY * 0.35,
                radiusX * 0.05,
                x,
                y,
                radiusX
            );

        dialGradient.addColorStop(
            0,
            '#3a3937'
        );

        dialGradient.addColorStop(
            0.55,
            '#262523'
        );

        dialGradient.addColorStop(
            1,
            '#121211'
        );

        ctx.fillStyle =
            dialGradient;

        ctx.beginPath();

        ctx.ellipse(
            x,
            y,
            radiusX,
            radiusY,
            0,
            0,
            Math.PI * 2
        );

        ctx.fill();

        /*
         * Inner dial border.
         */

        ctx.strokeStyle =
            'rgba(201,162,77,0.72)';

        ctx.lineWidth =
            Math.max(
                2,
                width * 0.006
            );

        ctx.stroke();


        /*
         * Hour markers.
         */

        for (
            let i = 0;
            i < 60;
            i++
        ) {

            const angle =
                (
                    i *
                    Math.PI *
                    2 /
                    60
                ) -
                Math.PI / 2;

            const isHour =
                i % 5 === 0;

            const outerX =
                x +
                Math.cos(angle) *
                radiusX *
                0.90;

            const outerY =
                y +
                Math.sin(angle) *
                radiusY *
                0.90;

            const innerFactor =
                isHour
                    ? 0.79
                    : 0.84;

            const innerX =
                x +
                Math.cos(angle) *
                radiusX *
                innerFactor;

            const innerY =
                y +
                Math.sin(angle) *
                radiusY *
                innerFactor;

            ctx.beginPath();

            ctx.moveTo(
                innerX,
                innerY
            );

            ctx.lineTo(
                outerX,
                outerY
            );

            ctx.strokeStyle =
                isHour
                    ? '#b58b36'
                    : 'rgba(181,139,54,0.55)';

            ctx.lineWidth =
                isHour
                    ? Math.max(
                        3,
                        width * 0.009
                    )
                    : Math.max(
                        1,
                        width * 0.0035
                    );

            ctx.stroke();

        }


        /*
         * Main 12 o'clock marker.
         */

        ctx.fillStyle =
            '#d0a74f';

        ctx.fillRect(
            x -
                width * 0.014,
            y -
                radiusY *
                0.91,
            width *
                0.028,
            height *
                0.075
        );


        /*
         * Subtle inner chapter ring.
         */

        ctx.beginPath();

        ctx.ellipse(
            x,
            y,
            radiusX * 0.74,
            radiusY * 0.74,
            0,
            0,
            Math.PI * 2
        );

        ctx.strokeStyle =
            'rgba(201,162,77,0.10)';

        ctx.lineWidth = 1;

        ctx.stroke();


        /*
         * Brand mark.
         */

        ctx.fillStyle =
            'rgba(243,237,224,0.72)';

        ctx.font =
            `${Math.max(9, width * 0.028)}px Georgia`;

        ctx.textAlign = 'center';

        ctx.letterSpacing = '2px';

        ctx.fillText(
            'UJJAYINI',
            x,
            y -
                radiusY *
                0.30
        );


        /*
         * Small horology text.
         */

        ctx.fillStyle =
            'rgba(201,162,77,0.65)';

        ctx.font =
            `${Math.max(5, width * 0.013)}px Arial`;

        ctx.fillText(
            'MAISON OF VEDIC HOROLOGY',
            x,
            y -
                radiusY *
                0.21
        );


        /*
         * Center jewel.
         */

        const jewelGradient =
            ctx.createRadialGradient(
                x -
                    width * 0.01,
                y -
                    width * 0.01,
                1,
                x,
                y,
                width * 0.035
            );

        jewelGradient.addColorStop(
            0,
            '#f5d57a'
        );

        jewelGradient.addColorStop(
            0.5,
            '#c9a24d'
        );

        jewelGradient.addColorStop(
            1,
            '#6e4a11'
        );

        ctx.fillStyle =
            jewelGradient;

        ctx.beginPath();

        ctx.arc(
            x,
            y,
            width * 0.028,
            0,
            Math.PI * 2
        );

        ctx.fill();

        ctx.restore();

    }


    /* =====================================================
       HANDS
    ===================================================== */

    drawHands(
        x,
        y,
        width,
        height,
        rotation
    ) {

        const ctx = this.ctx;

        /*
         * Slightly ceremonial time position.
         */

        const hour =
            10.2;

        const minute =
            2.4;

        const second =
            36;

        const hourAngle =
            (
                hour *
                Math.PI /
                6
            ) -
            Math.PI / 2;

        const minuteAngle =
            (
                minute *
                Math.PI /
                30
            ) -
            Math.PI / 2;

        const secondAngle =
            (
                second *
                Math.PI /
                30
            ) -
            Math.PI / 2;


        /*
         * Hour hand.
         */

        this.drawHand(
            x,
            y,
            hourAngle,
            width * 0.24,
            width * 0.022,
            '#15130f'
        );


        /*
         * Minute hand.
         */

        this.drawHand(
            x,
            y,
            minuteAngle,
            width * 0.32,
            width * 0.015,
            '#17140e'
        );


        /*
         * Seconds hand.
         */

        this.drawHand(
            x,
            y,
            secondAngle,
            width * 0.36,
            width * 0.005,
            '#a77b25'
        );


        /*
         * Center cap.
         */

        const centerGradient =
            ctx.createRadialGradient(
                x -
                    width * 0.007,
                y -
                    width * 0.007,
                1,
                x,
                y,
                width * 0.032
            );

        centerGradient.addColorStop(
            0,
            '#f0c96d'
        );

        centerGradient.addColorStop(
            0.5,
            '#c9a24d'
        );

        centerGradient.addColorStop(
            1,
            '#5d3d0e'
        );

        ctx.fillStyle =
            centerGradient;

        ctx.beginPath();

        ctx.arc(
            x,
            y,
            width * 0.032,
            0,
            Math.PI * 2
        );

        ctx.fill();

    }


    drawHand(
        x,
        y,
        angle,
        length,
        thickness,
        color
    ) {

        const ctx = this.ctx;

        const endX =
            x +
            Math.cos(angle) *
            length;

        const endY =
            y +
            Math.sin(angle) *
            length;

        ctx.save();

        ctx.beginPath();

        ctx.moveTo(
            x,
            y
        );

        ctx.lineTo(
            endX,
            endY
        );

        ctx.strokeStyle =
            color;

        ctx.lineWidth =
            thickness;

        ctx.lineCap =
            'round';

        ctx.shadowColor =
            'rgba(0,0,0,0.5)';

        ctx.shadowBlur = 4;

        ctx.stroke();

        ctx.restore();

    }


    /* =====================================================
       GLASS
    ===================================================== */

    drawGlass(
        x,
        y,
        width,
        height,
        rotation
    ) {

        const ctx = this.ctx;

        const radiusX =
            width * 0.415;

        const radiusY =
            height * 0.415;

        ctx.save();

        /*
         * Glass surface.
         */

        const glassGradient =
            ctx.createRadialGradient(
                x -
                    radiusX * 0.38,
                y -
                    radiusY * 0.40,
                radiusX * 0.05,
                x,
                y,
                radiusX
            );

        glassGradient.addColorStop(
            0,
            'rgba(255,255,255,0.035)'
        );

        glassGradient.addColorStop(
            0.45,
            'rgba(255,255,255,0.008)'
        );

        glassGradient.addColorStop(
            1,
            'rgba(0,0,0,0.06)'
        );

        ctx.fillStyle =
            glassGradient;

        ctx.beginPath();

        ctx.ellipse(
            x,
            y,
            radiusX,
            radiusY,
            0,
            0,
            Math.PI * 2
        );

        ctx.fill();


        /*
         * Luxury glass reflection.
         */

        ctx.save();

        ctx.beginPath();

        ctx.ellipse(
            x,
            y,
            radiusX,
            radiusY,
            0,
            0,
            Math.PI * 2
        );

        ctx.clip();


        /*
         * Diagonal highlight.
         */

        const reflection =
            ctx.createLinearGradient(
                x -
                    radiusX,
                y -
                    radiusY,
                x +
                    radiusX,
                y +
                    radiusY
            );

        reflection.addColorStop(
            0,
            'rgba(255,255,255,0)'
        );

        reflection.addColorStop(
            0.38,
            'rgba(255,255,255,0)'
        );

        reflection.addColorStop(
            0.48,
            'rgba(255,255,255,0.11)'
        );

        reflection.addColorStop(
            0.54,
            'rgba(255,255,255,0.025)'
        );

        reflection.addColorStop(
            0.68,
            'rgba(255,255,255,0)'
        );

        ctx.fillStyle =
            reflection;

        ctx.rotate(
            -0.28
        );

        ctx.fillRect(
            x -
                radiusX * 1.5,
            y -
                radiusY * 1.5,
            radiusX * 3,
            radiusY * 3
        );

        ctx.restore();


        /*
         * Glass rim.
         */

        ctx.beginPath();

        ctx.ellipse(
            x,
            y,
            radiusX,
            radiusY,
            0,
            0,
            Math.PI * 2
        );

        ctx.strokeStyle =
            'rgba(255,255,255,0.18)';

        ctx.lineWidth =
            Math.max(
                1,
                width * 0.003
            );

        ctx.stroke();

        ctx.restore();

    }


    /* =====================================================
       EXPLORE BUTTON
    ===================================================== */

    handleExplore() {

        /*
         * The next section can later be
         * connected here.
         */

        const nextSection =
            this.template.host
                .nextElementSibling;

        if (nextSection) {

            nextSection.scrollIntoView({
                behavior: 'smooth'
            });

        }

    }

}