import { LightningElement, wire } from 'lwc';

import getCollectionsWithWatches
    from '@salesforce/apex/UJJAYINICollectionController.getCollectionsWithWatches';

import HERO_IMAGE
    from '@salesforce/resourceUrl/UJJAYINI_Collections_Hero';


// =========================================================
// CONTENT
// The editorial story of each collection. Edit freely: these
// are the House's words, not data from Salesforce.
// =========================================================

const STORIES = {
    indranila: {
        accent: 'indranila',
        spirit: 'moon',
        spiritName: 'Neel',
        spiritLine: 'I keep the hours after midnight.',
        signature: 'SAPPHIRE · MIDNIGHT',
        tagline: 'The depth of midnight. The brilliance of sapphire.',
        inspiration: 'Named for the sapphire of Indra, the blue of the sky in the last minute of dusk. Indranīla remembers the nights when the astronomers of Ujjayini read time from the stars.',
        material: 'Deep-blue sapphire tones, midnight enamel dials and cool white metals, chosen to hold light the way the night sky does.',
        complication: 'Dials composed like a star chart, with markers that glow softly when the lights go down.'
    },
    hiranya: {
        accent: 'hiranya',
        spirit: 'sun',
        spiritName: 'Suvarna',
        spiritLine: 'Every dawn, I polish the gold.',
        signature: 'GOLD · DAWN',
        tagline: 'Gold forged into memory. Radiance made eternal.',
        inspiration: 'Hiranya is the Sanskrit word for gold: the first light of dawn over the Shipra, caught and kept on the wrist.',
        material: 'Yellow and rose gold tones, hand-finished cases and gem-set bezels that warm with the light around them.',
        complication: 'Open-worked, skeletonised dials that let you watch the heart of the watch at work.'
    },
    ayas: {
        accent: 'ayas',
        spirit: 'gear',
        spiritName: 'Loha',
        spiritLine: 'I never stop. I never rust.',
        signature: 'STEEL · ETERNAL',
        tagline: 'Steel shaped by precision. Permanence in every detail.',
        inspiration: 'Ayas is the oldest word for metal: the material of tools, instruments and things built to last generations.',
        material: 'Brushed and polished steel tones, sharp facets and strong bracelets made for daily wear.',
        complication: 'Precise, legible dials and sturdy construction for a life that moves.'
    }
};

const DEFAULT_STORY = {
    accent: 'house',
    spirit: 'sun',
    spiritName: 'Kala',
    spiritLine: 'Time is not simply measured.',
    signature: 'UJJAYINI · HOROLOGY',
    tagline: 'A distinctive expression of UJJAYINI horology.',
    inspiration: 'Every UJJAYINI collection begins with the same question: what does it mean to remember time?',
    material: 'Materials chosen for permanence and the way they hold light.',
    complication: 'A dial designed to be read in a glance and remembered for years.'
};

// "Find your expression": 3 questions, each answer adds points.
const QUESTIONS = [
    {
        key: 'occasion',
        number: '01',
        title: 'Where will it be worn most?',
        options: [
            { value: 'everyday', label: 'Every day', hint: 'Work, travel, life', score: { ayas: 2, indranila: 1 } },
            { value: 'evening', label: 'Evenings', hint: 'Dinners and quiet moments', score: { indranila: 2, hiranya: 1 } },
            { value: 'celebration', label: 'Celebrations', hint: 'Weddings, festivals, milestones', score: { hiranya: 2 } }
        ]
    },
    {
        key: 'material',
        number: '02',
        title: 'Which material speaks to you?',
        options: [
            { value: 'gold', label: 'Gold', hint: 'Warm and radiant', score: { hiranya: 3 } },
            { value: 'sapphire', label: 'Sapphire', hint: 'Deep and mysterious', score: { indranila: 3 } },
            { value: 'steel', label: 'Steel', hint: 'Strong and honest', score: { ayas: 3 } }
        ]
    },
    {
        key: 'dial',
        number: '03',
        title: 'And the dial?',
        options: [
            { value: 'skeleton', label: 'Skeleton', hint: 'Show me the heart', score: { hiranya: 2, ayas: 1 } },
            { value: 'minimal', label: 'Minimal', hint: 'Quiet and clean', score: { ayas: 2, indranila: 1 } },
            { value: 'jewelled', label: 'Jewelled', hint: 'Let it sparkle', score: { indranila: 2, hiranya: 1 } }
        ]
    }
];

const RESULT_KEY = 'ujjayini.expression';

const PETAL_COUNT = 16;

function norm(value) {
    return (value || '')
        .toString()
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .toLowerCase()
        .trim();
}

function cloudinary(url, transform) {

    if (!url || url.indexOf('res.cloudinary.com') === -1 || url.indexOf('/upload/') === -1) {
        return url;
    }

    return url.replace('/upload/', '/upload/' + transform + '/');
}

function pad(n) {
    return String(n).padStart(2, '0');
}


export default class UjjayiniCollectionSection extends LightningElement {

    collections = [];
    errorMessage;
    isLoading = true;

    active = 0;
    flippedKey;

    // Quiz
    quizOpen = false;
    quizStep = 0;
    answers = {};
    resultKey;

    _swipe;


    // =========================================================
    // LIFECYCLE
    // =========================================================

    connectedCallback() {

        try {
            this.resultKey = window.localStorage.getItem(RESULT_KEY) || undefined;
        } catch (e) {
            this.resultKey = undefined;
        }
    }


    // =========================================================
    // DATA
    // =========================================================

    @wire(getCollectionsWithWatches)
    wiredCollections({ data, error }) {

        if (data) {

            this.collections = data.map(collection => ({
                ...collection,
                key: norm(collection.name)
            }));

            this.errorMessage = undefined;
            this.isLoading = false;

            // Open on the visitor's expression, if they found one before.
            const remembered = this.collections.findIndex(c => c.key === this.resultKey);
            if (remembered >= 0) {
                this.active = remembered;
            } else if (this.collections.length >= 3) {
                this.active = 1;
            }

        } else if (error) {

            this.collections = [];
            this.isLoading = false;
            this.errorMessage = 'The collections are resting for a moment. Please refresh the page.';
        }
    }

    get hasCollections() {
        return this.collections.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && !this.errorMessage && this.collections.length === 0;
    }


    // =========================================================
    // CAROUSEL
    // =========================================================

    get cards() {

        const total = this.collections.length;

        return this.collections.map((collection, index) => {

            const story = STORIES[collection.key] || DEFAULT_STORY;

            // Position relative to the active card: -1 left, 0 centre, 1 right
            let offset = index - this.active;
            if (total > 2) {
                if (offset > total / 2) { offset -= total; }
                if (offset < -total / 2) { offset += total; }
            }

            let position = 'is-hidden';
            if (offset === 0) { position = 'is-center'; }
            else if (offset === -1) { position = 'is-left'; }
            else if (offset === 1) { position = 'is-right'; }

            const isMatch = this.resultKey && this.resultKey === collection.key;
            const flipped = this.flippedKey === collection.key;

            let className = 'card theme-' + story.accent + ' ' + position;
            if (isMatch) { className += ' is-match'; }

            const watches = (collection.watches || []).slice(0, 4).map(watch => ({
                productId: watch.productId,
                name: watch.name,
                style: watch.imageUrl
                    ? 'background-image:url("' + cloudinary(watch.imageUrl, 'f_auto,q_auto,w_200,h_200,c_fill') + '");'
                    : ''
            }));

            return {
                key: collection.key || String(index),
                collectionId: collection.collectionId,
                name: collection.name,
                number: pad(index + 1),
                index: String(index),
                className,
                flipClass: flipped ? 'flip is-flipped' : 'flip',
                isCenter: offset === 0,
                ariaHidden: offset === 0 ? 'false' : 'true',
                imageStyle: collection.heroImageUrl
                    ? 'background-image:url("' + cloudinary(collection.heroImageUrl, 'f_auto,q_auto,c_limit,w_1100') + '");'
                    : '',
                hasImage: !!collection.heroImageUrl,
                tagline: collection.shortDescription || story.tagline,
                signature: story.signature,
                inspiration: story.inspiration,
                material: story.material,
                complication: story.complication,
                spiritClass: 'spirit spirit-' + story.spirit,
                spiritName: story.spiritName,
                spiritLine: story.spiritLine,
                watches,
                hasWatches: watches.length > 0,
                watchCount: (collection.watches || []).length,
                storyLabel: flipped ? '← THE DIAL' : 'THE STORY',
                matchLabel: isMatch ? 'YOUR EXPRESSION' : ''
            };
        });
    }

    get dots() {
        return this.collections.map((collection, index) => ({
            key: 'd' + index,
            index: String(index),
            label: collection.name,
            className: index === this.active ? 'dot is-on' : 'dot'
        }));
    }

    get activeName() {
        const current = this.collections[this.active];
        return current ? current.name : '';
    }

    get activeCounter() {
        return pad(this.active + 1) + ' / ' + pad(this.collections.length);
    }

    go(index) {
        const total = this.collections.length;
        if (!total) {
            return;
        }
        this.active = ((index % total) + total) % total;
        this.flippedKey = undefined;
    }

    handlePrev() {
        this.go(this.active - 1);
    }

    handleNext() {
        this.go(this.active + 1);
    }

    handleDot(event) {
        this.go(Number(event.currentTarget.dataset.index));
    }

    handleCardClick(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (index !== this.active) {
            this.go(index);
        }
    }

    handleStageKey(event) {
        if (event.key === 'ArrowLeft') {
            event.preventDefault();
            this.handlePrev();
        } else if (event.key === 'ArrowRight') {
            event.preventDefault();
            this.handleNext();
        }
    }

    handlePointerDown(event) {
        this._swipe = { x: event.clientX, y: event.clientY };
    }

    handlePointerUp(event) {

        if (!this._swipe) {
            return;
        }

        const dx = event.clientX - this._swipe.x;
        const dy = event.clientY - this._swipe.y;
        this._swipe = undefined;

        if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.4) {
            if (dx < 0) {
                this.handleNext();
            } else {
                this.handlePrev();
            }
        }
    }

    toggleStory(event) {
        event.stopPropagation();
        const key = event.currentTarget.dataset.key;
        this.flippedKey = this.flippedKey === key ? undefined : key;
    }

    exploreWatches(event) {
        event.stopPropagation();
        const key = event.currentTarget.dataset.key;
        window.location.href = '/ujjayini/watches' + (key ? '?collection=' + encodeURIComponent(key) : '');
    }

    openWatch(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        if (id) {
            window.location.href = '/ujjayini/product-detail?productId=' + encodeURIComponent(id);
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    scrollToShowcase() {
        const target = this.template.querySelector('.showcase');
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }


    // =========================================================
    // FIND YOUR EXPRESSION (quiz)
    // =========================================================

    get hasResult() {
        return !!this.resultKey && this.collections.some(c => c.key === this.resultKey);
    }

    get resultName() {
        const match = this.collections.find(c => c.key === this.resultKey);
        return match ? match.name : '';
    }

    get quizQuestion() {
        return QUESTIONS[this.quizStep];
    }

    get quizOptions() {

        const question = QUESTIONS[this.quizStep];
        const chosen = this.answers[question.key];

        return question.options.map(option => ({
            ...option,
            key: question.key + option.value,
            className: chosen === option.value ? 'option is-on' : 'option'
        }));
    }

    get quizProgress() {
        return QUESTIONS.map((q, index) => ({
            key: q.key,
            className: index < this.quizStep ? 'step is-done' : (index === this.quizStep ? 'step is-on' : 'step')
        }));
    }

    get canGoBack() {
        return this.quizStep > 0;
    }

    openQuiz() {
        this.quizStep = 0;
        this.answers = {};
        this.quizOpen = true;
    }

    closeQuiz() {
        this.quizOpen = false;
    }

    quizBack() {
        if (this.quizStep > 0) {
            this.quizStep -= 1;
        }
    }

    chooseOption(event) {

        const question = QUESTIONS[this.quizStep];
        const value = event.currentTarget.dataset.value;

        this.answers = { ...this.answers, [question.key]: value };

        if (this.quizStep < QUESTIONS.length - 1) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.quizStep += 1;
            }, 260);
            return;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.finishQuiz(), 320);
    }

    finishQuiz() {

        const totals = { indranila: 0, hiranya: 0, ayas: 0 };

        QUESTIONS.forEach(question => {
            const option = question.options.find(o => o.value === this.answers[question.key]);
            if (option) {
                Object.keys(option.score).forEach(key => {
                    totals[key] += option.score[key];
                });
            }
        });

        // The material answer breaks any tie.
        const materialOrder = { gold: 'hiranya', sapphire: 'indranila', steel: 'ayas' };
        const tieBreaker = materialOrder[this.answers.material];

        const winner = Object.keys(totals).sort((a, b) =>
            (totals[b] - totals[a]) || (b === tieBreaker ? 1 : 0) - (a === tieBreaker ? 1 : 0)
        )[0];

        this.resultKey = winner;

        try {
            window.localStorage.setItem(RESULT_KEY, winner);
        } catch (e) {
            // Remembered only for this visit.
        }

        this.quizOpen = false;

        const index = this.collections.findIndex(c => c.key === winner);
        if (index >= 0) {
            this.go(index);
        }

        this.scrollToShowcase();
    }

    clearResult() {

        this.resultKey = undefined;

        try {
            window.localStorage.removeItem(RESULT_KEY);
        } catch (e) {
            // Nothing stored.
        }
    }


    // =========================================================
    // HERO
    // =========================================================

    get heroPhotoStyle() {
        return 'background-image:url("' + HERO_IMAGE + '");';
    }

    // Spring: palash (flame-of-the-forest) petals drifting across
    get petals() {

        const petals = [];

        for (let i = 0; i < PETAL_COUNT; i++) {
            const left = (i * 61) % 100;
            const delay = (i * 1.7) % 14;
            const duration = 12 + (i % 5) * 2.4;
            const size = 8 + (i % 4) * 3;

            petals.push({
                key: 'p' + i,
                className: i % 3 === 0 ? 'petal is-violet' : 'petal',
                style: 'left:' + left + '%;animation-delay:-' + delay.toFixed(1) + 's;animation-duration:' +
                    duration.toFixed(1) + 's;width:' + size + 'px;height:' + Math.round(size * 0.62) + 'px;'
            });
        }

        return petals;
    }
}