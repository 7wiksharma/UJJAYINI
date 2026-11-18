import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import THREE_JS from '@salesforce/resourceUrl/threejs';

const THREE_SCRIPT = THREE_JS;


// =========================================================
// CONTENT
// =========================================================

const CODE_PILLARS = [
    {
        id: 'precision',
        number: '01',
        title: 'PRECISION',
        copy:
            'A movement is judged by what it does when no one is watching.'
    },
    {
        id: 'permanence',
        number: '02',
        title: 'PERMANENCE',
        copy:
            'Cases, crystals and finishes made to outlast the hands that wear them.'
    },
    {
        id: 'craft',
        number: '03',
        title: 'CRAFT',
        copy:
            'Every surface resolved with care. Nothing hurried, nothing ornamental without reason.'
    },
    {
        id: 'memory',
        number: '04',
        title: 'MEMORY',
        copy:
            'A watch is worn through a life. It keeps the hours that mattered.'
    }
];

const HOUSE_COLLECTIONS = [
    {
        id: 'indranila',
        number: '01',
        name: 'Indranīla',
        tagline: 'The depth of midnight. The brilliance of sapphire.',
        signature: 'SAPPHIRE · MIDNIGHT'
    },
    {
        id: 'hiranya',
        number: '02',
        name: 'Hiranya',
        tagline: 'Gold forged into memory. Radiance made eternal.',
        signature: 'GOLD · DAWN'
    },
    {
        id: 'ayas',
        number: '03',
        name: 'Ayas',
        tagline: 'Steel shaped by precision. Permanence in every detail.',
        signature: 'STEEL · ETERNAL'
    }
];

// =========================================================
// SCENE CONSTANTS
// =========================================================

const GOLD = 0xc9a24d;
const IVORY = 0xf3ead7;
const SAPPHIRE = 0x4a6fd8;
const STEEL = 0xcfd4dc;

const PLANET_RADIUS = 3;
const TROPIC_TILT = 0.41; // about 23.5 degrees, in radians

// Where the eclipse planet sits while the page scrolls (p = 0..1)
const SCENE_KEYS = [
    { p: 0.0,  x: 4.4,  y: 0.1,  z: 0,   s: 1.0 },
    { p: 0.16, x: 4.4,  y: 0.1,  z: 0,   s: 1.0 },
    { p: 0.30, x: -4.6, y: -0.3, z: -2,  s: 0.9 },
    { p: 0.46, x: 0,    y: 0,    z: -10, s: 0.9 },
    { p: 0.70, x: 4.8,  y: -0.2, z: -4,  s: 0.85 },
    { p: 1.0,  x: 0,    y: 1.4,  z: -7,  s: 0.8 }
];

function smoothstep(t) {
    return t * t * (3 - 2 * t);
}

function sampleKeys(progress) {

    const p = Math.min(1, Math.max(0, progress));

    for (let i = 0; i < SCENE_KEYS.length - 1; i++) {

        const a = SCENE_KEYS[i];
        const b = SCENE_KEYS[i + 1];

        if (p >= a.p && p <= b.p) {

            const span = b.p - a.p;
            const t = span === 0 ? 0 : smoothstep((p - a.p) / span);

            return {
                x: a.x + (b.x - a.x) * t,
                y: a.y + (b.y - a.y) * t,
                z: a.z + (b.z - a.z) * t,
                s: a.s + (b.s - a.s) * t
            };

        }

    }

    const last = SCENE_KEYS[SCENE_KEYS.length - 1];

    return { x: last.x, y: last.y, z: last.z, s: last.s };

}


// =========================================================
// SHADERS (plain GLSL, works with any Three.js build)
// =========================================================

const RIM_VERTEX = `
varying vec3 vNormal;
void main() {
    vNormal = normalize(normalMatrix * normal);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

const RIM_FRAGMENT = `
uniform vec3 uColor;
uniform vec3 uLight;
varying vec3 vNormal;
void main() {
    vec3 n = normalize(vNormal);
    float rim = pow(1.0 - abs(n.z), 2.2);
    float lit = smoothstep(-0.15, 0.85, dot(n, normalize(uLight)));
    float a = rim * lit;
    gl_FragColor = vec4(uColor * a * 1.8, a);
}`;

const HALO_FRAGMENT = `
uniform vec3 uColor;
uniform vec3 uLight;
varying vec3 vNormal;
void main() {
    vec3 n = normalize(vNormal);
    float h = clamp(abs(n.z) / 0.55, 0.0, 1.0);
    float halo = pow(h, 2.0);
    float lit = 0.3 + 0.7 * smoothstep(-0.3, 0.9, dot(n, normalize(uLight)));
    float a = halo * lit;
    gl_FragColor = vec4(uColor * a, a);
}`;


// =========================================================
// SCENE HELPERS
// =========================================================

function makeTexture(THREE, stops) {

    const size = 128;

    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;

    const ctx = canvas.getContext('2d');

    const gradient = ctx.createRadialGradient(
        size / 2, size / 2, 0,
        size / 2, size / 2, size / 2
    );

    stops.forEach(([offset, color]) => {
        gradient.addColorStop(offset, color);
    });

    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, size, size);

    return new THREE.CanvasTexture(canvas);

}


function buildStars(THREE, track, count, rMin, rMax, size, texture, goldRatio) {

    const positions = new Float32Array(count * 3);
    const colors = new Float32Array(count * 3);

    const ivory = new THREE.Color(IVORY);
    const gold = new THREE.Color(GOLD);
    const violet = new THREE.Color(0x8a78c8);

    for (let i = 0; i < count; i++) {

        const r = rMin + Math.random() * (rMax - rMin);
        const theta = Math.random() * Math.PI * 2;
        const phi = Math.acos(2 * Math.random() - 1);

        positions[i * 3] = r * Math.sin(phi) * Math.cos(theta);
        positions[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta);
        positions[i * 3 + 2] = r * Math.cos(phi);

        const roll = Math.random();

        const base =
            roll < goldRatio
                ? gold
                : roll < goldRatio + 0.12
                    ? violet
                    : ivory;

        const k = 0.45 + Math.random() * 0.55;

        colors[i * 3] = base.r * k;
        colors[i * 3 + 1] = base.g * k;
        colors[i * 3 + 2] = base.b * k;

    }

    const geometry = track(new THREE.BufferGeometry());

    geometry.setAttribute(
        'position',
        new THREE.BufferAttribute(positions, 3)
    );

    geometry.setAttribute(
        'color',
        new THREE.BufferAttribute(colors, 3)
    );

    const material = track(new THREE.PointsMaterial({
        size,
        map: texture,
        vertexColors: true,
        transparent: true,
        opacity: 0.95,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
        sizeAttenuation: true
    }));

    return new THREE.Points(geometry, material);

}


function buildScene(THREE, canvas, isMobile) {

    const disposables = [];

    const track = item => {
        disposables.push(item);
        return item;
    };

    const renderer = new THREE.WebGLRenderer({
        canvas,
        antialias: !isMobile,
        alpha: true
    });

    renderer.setClearColor(0x000000, 0);

    const scene = new THREE.Scene();

    const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 400);
    camera.position.set(0, 0, 14);

    // ----- textures -----
    const starTexture = track(makeTexture(THREE, [
        [0, 'rgba(255,255,255,1)'],
        [0.35, 'rgba(255,255,255,0.55)'],
        [1, 'rgba(255,255,255,0)']
    ]));

    const flareTexture = track(makeTexture(THREE, [
        [0, 'rgba(255,244,214,1)'],
        [0.2, 'rgba(240,200,120,0.7)'],
        [0.55, 'rgba(201,162,77,0.18)'],
        [1, 'rgba(201,162,77,0)']
    ]));

    const glowTexture = track(makeTexture(THREE, [
        [0, 'rgba(255,255,255,1)'],
        [0.3, 'rgba(255,255,255,0.45)'],
        [1, 'rgba(255,255,255,0)']
    ]));

    const ringTexture = track(makeTexture(THREE, [
        [0, 'rgba(0,0,0,0)'],
        [0.7, 'rgba(0,0,0,0)'],
        [0.82, 'rgba(255,255,255,0.9)'],
        [0.9, 'rgba(255,255,255,0.2)'],
        [1, 'rgba(255,255,255,0)']
    ]));

    // ----- stars (two depth layers) -----
    const farStars = buildStars(
        THREE, track,
        isMobile ? 600 : 1500,
        55, 120, 0.2, starTexture, 0.18
    );

    const nearStars = buildStars(
        THREE, track,
        isMobile ? 150 : 350,
        18, 40, 0.07, starTexture, 0.5
    );

    scene.add(farStars);
    scene.add(nearStars);

    // ----- planet group (eclipse + instrument) -----
    const planet = new THREE.Group();
    scene.add(planet);

    const lightDirection = new THREE.Vector3(0.82, 0.32, 0.46).normalize();

    const body = new THREE.Mesh(
        track(new THREE.SphereGeometry(PLANET_RADIUS, 64, 64)),
        track(new THREE.MeshBasicMaterial({ color: 0x030308 }))
    );

    planet.add(body);

    const rim = new THREE.Mesh(
        track(new THREE.SphereGeometry(PLANET_RADIUS * 1.003, 64, 64)),
        track(new THREE.ShaderMaterial({
            uniforms: {
                uColor: { value: new THREE.Color(GOLD) },
                uLight: { value: lightDirection }
            },
            vertexShader: RIM_VERTEX,
            fragmentShader: RIM_FRAGMENT,
            transparent: true,
            blending: THREE.AdditiveBlending,
            depthWrite: false
        }))
    );

    planet.add(rim);

    const halo = new THREE.Mesh(
        track(new THREE.SphereGeometry(PLANET_RADIUS * 1.18, 64, 64)),
        track(new THREE.ShaderMaterial({
            uniforms: {
                uColor: { value: new THREE.Color(0xe0b862) },
                uLight: { value: lightDirection }
            },
            vertexShader: RIM_VERTEX,
            fragmentShader: HALO_FRAGMENT,
            transparent: true,
            blending: THREE.AdditiveBlending,
            side: THREE.BackSide,
            depthWrite: false
        }))
    );

    planet.add(halo);

    // ----- sun flare behind the planet -----
    const flare = new THREE.Sprite(track(new THREE.SpriteMaterial({
        map: flareTexture,
        transparent: true,
        blending: THREE.AdditiveBlending,
        depthWrite: false
    })));

    flare.position.set(
        PLANET_RADIUS * 1.2,
        PLANET_RADIUS * 0.45,
        -PLANET_RADIUS * 0.9
    );

    flare.scale.set(9, 9, 1);
    planet.add(flare);

    const streak = new THREE.Sprite(track(new THREE.SpriteMaterial({
        map: flareTexture,
        transparent: true,
        opacity: 0.8,
        blending: THREE.AdditiveBlending,
        depthWrite: false
    })));

    streak.position.copy(flare.position);
    streak.scale.set(20, 0.28, 1);
    planet.add(streak);

    // ----- Ujjain marker on the planet surface -----
    const lat = (23.18 * Math.PI) / 180;
    const lon = 0.95;

    const surface = new THREE.Vector3(
        Math.cos(lat) * Math.sin(lon),
        Math.sin(lat),
        Math.cos(lat) * Math.cos(lon)
    ).multiplyScalar(PLANET_RADIUS * 1.012);

    const dotCore = new THREE.Sprite(track(new THREE.SpriteMaterial({
        map: glowTexture,
        color: 0xfff0c8,
        transparent: true,
        blending: THREE.AdditiveBlending,
        depthWrite: false
    })));

    dotCore.position.copy(surface);
    dotCore.scale.set(0.3, 0.3, 1);
    planet.add(dotCore);

    const dotHalo = new THREE.Sprite(track(new THREE.SpriteMaterial({
        map: glowTexture,
        color: GOLD,
        transparent: true,
        blending: THREE.AdditiveBlending,
        depthWrite: false
    })));

    dotHalo.position.copy(surface);
    dotHalo.scale.set(1.1, 1.1, 1);
    planet.add(dotHalo);

    const pulses = [0, 0.5].map(offset => {

        const sprite = new THREE.Sprite(track(new THREE.SpriteMaterial({
            map: ringTexture,
            color: GOLD,
            transparent: true,
            blending: THREE.AdditiveBlending,
            depthWrite: false
        })));

        sprite.position.copy(surface);
        planet.add(sprite);

        return { sprite, offset };

    });

    // ----- armillary instrument -----
    const armillary = new THREE.Group();
    armillary.rotation.set(0.18, 0, -0.32);
    planet.add(armillary);

    const orbits = [];

    const markerGeometry = track(new THREE.SphereGeometry(0.11, 16, 16));

    const addOrbit = (rotation, radius, ringOpacity, markerColor, speed, phase) => {

        const holder = new THREE.Group();
        holder.rotation.set(rotation[0], rotation[1], rotation[2]);

        const ring = new THREE.Mesh(
            track(new THREE.TorusGeometry(radius, 0.014, 6, 256)),
            track(new THREE.MeshBasicMaterial({
                color: GOLD,
                transparent: true,
                opacity: ringOpacity
            }))
        );

        holder.add(ring);

        const pivot = new THREE.Group();
        holder.add(pivot);

        const marker = new THREE.Mesh(
            markerGeometry,
            track(new THREE.MeshBasicMaterial({ color: markerColor }))
        );

        marker.position.set(radius, 0, 0);
        pivot.add(marker);

        const glow = new THREE.Sprite(track(new THREE.SpriteMaterial({
            map: glowTexture,
            color: markerColor,
            transparent: true,
            blending: THREE.AdditiveBlending,
            depthWrite: false
        })));

        glow.scale.set(0.95, 0.95, 1);
        marker.add(glow);

        armillary.add(holder);

        orbits.push({ pivot, speed, phase });

    };

    // Equator (steel / Ayas)
    addOrbit([Math.PI / 2, 0, 0], 4.6, 0.8, STEEL, 0.2, 0.4);

    // Ecliptic, tilted 23.5 degrees (gold / Hiranya)
    addOrbit([Math.PI / 2 + TROPIC_TILT, 0, 0], 5.3, 0.55, GOLD, -0.14, 2.1);

    // Meridian (sapphire / Indranila)
    addOrbit([0, Math.PI / 2, 0], 6.0, 0.4, SAPPHIRE, 0.1, 4.0);

    // ----- sky dial: 120 ticks, 12 hour marks -----
    const dial = new THREE.Group();
    dial.rotation.set(-0.45, 0.35, 0);
    planet.add(dial);

    const dialRadius = 7.4;
    const ticks = [];

    for (let i = 0; i < 120; i++) {

        const angle = (i / 120) * Math.PI * 2;
        const isHour = i % 10 === 0;
        const isMid = i % 5 === 0;
        const length = isHour ? 0.42 : isMid ? 0.26 : 0.12;
        const c = Math.cos(angle);
        const s = Math.sin(angle);

        ticks.push(
            dialRadius * c, dialRadius * s, 0,
            (dialRadius - length) * c, (dialRadius - length) * s, 0
        );

    }

    const tickGeometry = track(new THREE.BufferGeometry());

    tickGeometry.setAttribute(
        'position',
        new THREE.BufferAttribute(new Float32Array(ticks), 3)
    );

    dial.add(new THREE.LineSegments(
        tickGeometry,
        track(new THREE.LineBasicMaterial({
            color: GOLD,
            transparent: true,
            opacity: 0.55
        }))
    ));

    dial.add(new THREE.Mesh(
        track(new THREE.TorusGeometry(dialRadius + 0.03, 0.01, 6, 256)),
        track(new THREE.MeshBasicMaterial({
            color: GOLD,
            transparent: true,
            opacity: 0.4
        }))
    ));

    return {
        renderer,
        scene,
        camera,
        planet,
        armillary,
        dial,
        orbits,
        pulses,
        farStars,
        nearStars,
        dotHalo,
        disposables
    };

}


// =========================================================
// COMPONENT
// =========================================================

export default class UjjayiniAboutUs extends LightningElement {

    codePillars = CODE_PILLARS;

    houseCollections = HOUSE_COLLECTIONS;

    _initialized = false;

    _revealObserver;

    // scene state
    _ctx = null;
    _page = null;
    _layer = null;
    _running = false;
    _rafId = 0;
    _pageVisible = true;
    _disposed = false;
    _mobile = false;
    _reduceMotion = false;
    _progTarget = 0;
    _prog = 0;
    _cur = { x: 4.4, y: 0.1, z: 0, s: 1 };
    _mouse = { x: 0, y: 0 };
    _pageObserver;

    _onMouseMove = event => {

        this._mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
        this._mouse.y = (event.clientY / window.innerHeight) * 2 - 1;

    };

    _onResize = () => {

        this._resize();

        if (this._reduceMotion) {
            this._frame(0);
        }

    };

    _onVisibility = () => {

        if (document.hidden) {
            this._stop();
        } else if (this._pageVisible) {
            this._start();
        }

    };

    _onScrollStatic = () => {

        if (this._reduceMotion && this._ctx) {
            this._frame(0);
        }

    };

    _tick = now => {

        if (!this._running) {
            return;
        }

        this._rafId = window.requestAnimationFrame(this._tick);

        this._frame(now / 1000);

    };


    // =========================================================
    // LIFECYCLE
    // =========================================================

    renderedCallback() {

        if (this._initialized) {
            return;
        }

        const page =
            this.template.querySelector('.about-page');

        if (!page) {
            return;
        }

        this._initialized = true;
        this._page = page;

        this._reduceMotion =
            !!(
                window.matchMedia &&
                window.matchMedia(
                    '(prefers-reduced-motion: reduce)'
                ).matches
            );

        this._initReveal(page);

        this._initScene(page);

    }


    disconnectedCallback() {

        this._disposed = true;

        if (this._revealObserver) {
            this._revealObserver.disconnect();
            this._revealObserver = null;
        }

        this._disposeScene();

    }


    // =========================================================
    // SCROLL REVEAL
    // =========================================================

    _initReveal(page) {

        const items =
            this.template.querySelectorAll('.reveal');

        if (
            this._reduceMotion ||
            typeof IntersectionObserver === 'undefined'
        ) {

            items.forEach(item => {
                item.classList.add('is-visible');
            });

            return;

        }

        page.classList.add('is-ready');

        this._revealObserver = new IntersectionObserver(

            (entries, observer) => {

                entries.forEach(entry => {

                    if (entry.isIntersecting) {

                        entry.target.classList.add('is-visible');

                        observer.unobserve(entry.target);

                    }

                });

            },

            {
                threshold: 0.12,
                rootMargin: '0px 0px -6% 0px'
            }

        );

        items.forEach(item => {
            this._revealObserver.observe(item);
        });

    }


    // =========================================================
    // 3D SCENE
    // =========================================================

    async _initScene(page) {

        try {

            await loadScript(this, THREE_SCRIPT);

            if (this._disposed) {
                return;
            }

            const THREE = window.THREE;

            if (!THREE) {
                throw new Error('THREE global not found after loadScript');
            }

            const canvas =
                this.template.querySelector('.scene-canvas');

            this._layer =
                this.template.querySelector('.scene-layer');

            if (!canvas || !this._layer) {
                return;
            }

            this._mobile = this._layer.clientWidth < 820;

            this._ctx = buildScene(THREE, canvas, this._mobile);

            this._resize();

            window.addEventListener('resize', this._onResize);

            if (!this._reduceMotion) {

                window.addEventListener('mousemove', this._onMouseMove, {
                    passive: true
                });

                document.addEventListener(
                    'visibilitychange',
                    this._onVisibility
                );

                if (typeof IntersectionObserver !== 'undefined') {

                    this._pageObserver = new IntersectionObserver(
                        entries => {

                            this._pageVisible = entries[0].isIntersecting;

                            if (this._pageVisible && !document.hidden) {
                                this._start();
                            } else {
                                this._stop();
                            }

                        }
                    );

                    this._pageObserver.observe(page);

                }

                this._start();

            } else {

                window.addEventListener('scroll', this._onScrollStatic, {
                    passive: true,
                    capture: true
                });

                this._frame(0);

            }

            page.classList.add('scene-live');

        } catch (error) {

            // CSS fallback stays visible. The page still works.
            // eslint-disable-next-line no-console
            console.warn('UJJAYINI 3D scene unavailable:', error);

        }

    }


    _resize() {

        const c = this._ctx;

        if (!c || !this._layer) {
            return;
        }

        const width = this._layer.clientWidth || window.innerWidth;
        const height = this._layer.clientHeight || window.innerHeight;

        this._mobile = width < 820;

        c.renderer.setPixelRatio(
            Math.min(window.devicePixelRatio || 1, this._mobile ? 1.5 : 2)
        );

        c.renderer.setSize(width, height, false);

        c.camera.aspect = width / height;

        c.camera.position.z = c.camera.aspect < 0.9 ? 19 : 14;

        c.camera.updateProjectionMatrix();

    }


    _start() {

        if (this._running || this._reduceMotion || !this._ctx) {
            return;
        }

        this._running = true;

        this._rafId = window.requestAnimationFrame(this._tick);

    }


    _stop() {

        this._running = false;

        if (this._rafId) {
            window.cancelAnimationFrame(this._rafId);
            this._rafId = 0;
        }

    }


    _updateProgress() {

        if (!this._page) {
            return;
        }

        const rect = this._page.getBoundingClientRect();

        const total = rect.height - window.innerHeight;

        this._progTarget =
            total > 0
                ? Math.min(1, Math.max(0, -rect.top / total))
                : 0;

    }


    _frame(t) {

        const c = this._ctx;

        if (!c) {
            return;
        }

        this._updateProgress();

        const snap = this._reduceMotion ? 1 : 1;
        const ease = this._reduceMotion ? snap : 0.07;

        this._prog += (this._progTarget - this._prog) * ease;

        const key = sampleKeys(this._prog);

        const targetX = key.x * (this._mobile ? 0.25 : 1);
        const targetY = key.y + (this._mobile ? 1.4 : 0);
        const targetScale = key.s * (this._mobile ? 0.72 : 1);

        const move = this._reduceMotion ? 1 : 0.06;

        this._cur.x += (targetX - this._cur.x) * move;
        this._cur.y += (targetY - this._cur.y) * move;
        this._cur.z += (key.z - this._cur.z) * move;
        this._cur.s += (targetScale - this._cur.s) * move;

        c.planet.position.set(this._cur.x, this._cur.y, this._cur.z);
        c.planet.scale.setScalar(this._cur.s);

        const prog = this._prog;

        c.armillary.rotation.y = t * 0.045 + prog * 1.9;

        c.dial.rotation.z = -t * 0.018 + prog * 0.5;

        c.orbits.forEach(orbit => {
            orbit.pivot.rotation.z = orbit.phase + t * orbit.speed;
        });

        c.farStars.rotation.y = t * 0.003 + prog * 0.25;

        c.nearStars.rotation.y = -t * 0.006 - prog * 0.5;
        c.nearStars.rotation.x = prog * 0.15;

        // Ujjain marker pulse
        c.dotHalo.material.opacity = 0.65 + Math.sin(t * 2.2) * 0.25;

        c.pulses.forEach(pulse => {

            const phase = (t * 0.45 + pulse.offset) % 1;

            const size = 0.3 + phase * 1.6;

            pulse.sprite.scale.set(size, size, 1);

            pulse.sprite.material.opacity = (1 - phase) * 0.8;

        });

        // Mouse parallax
        c.camera.position.x +=
            (this._mouse.x * 0.7 - c.camera.position.x) * 0.04;

        c.camera.position.y +=
            (-this._mouse.y * 0.45 - c.camera.position.y) * 0.04;

        c.camera.lookAt(0, 0, 0);

        c.renderer.render(c.scene, c.camera);

    }


    _disposeScene() {

        this._stop();

        window.removeEventListener('resize', this._onResize);
        window.removeEventListener('mousemove', this._onMouseMove);
        window.removeEventListener('scroll', this._onScrollStatic, true);
        document.removeEventListener('visibilitychange', this._onVisibility);

        if (this._pageObserver) {
            this._pageObserver.disconnect();
            this._pageObserver = null;
        }

        const c = this._ctx;

        if (!c) {
            return;
        }

        c.disposables.forEach(item => {
            if (item && typeof item.dispose === 'function') {
                item.dispose();
            }
        });

        c.renderer.dispose();

        this._ctx = null;

    }


    // =========================================================
    // ACTIONS
    // =========================================================

    handleScrollDown() {

        const target =
            this.template.querySelector('.origin-section');

        if (target) {

            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });

        }

    }


    handleExplore() {

        window.location.href = '/ujjayini/watches';

    }

}