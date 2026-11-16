import { LightningElement } from 'lwc';

export default class UjjayiniCollectionSection extends LightningElement {
    /* Static copy for now. Later this can be fed from Collection__c (Name, Description__c). */
    collections = [
        {
            key: 'indranila',
            cardClass: 'collection-card indranila reveal',
            number: '01',
            category: 'CELESTIAL',
            name: 'INDRANĪLA',
            description:
                'Born beneath the quiet of the night, Indranīla carries the depth of the celestial sky within its measure.',
            footer: 'SAPPHIRE · MIDNIGHT'
        },
        {
            key: 'hiranya',
            cardClass: 'collection-card hiranya reveal',
            number: '02',
            category: 'RADIANCE',
            name: 'HIRANYA',
            description:
                'Inspired by the first light of dawn, Hiranya reflects time through warmth, brilliance and quiet opulence.',
            footer: 'GOLD · DAWN'
        },
        {
            key: 'ayas',
            cardClass: 'collection-card ayas reveal',
            number: '03',
            category: 'PERMANENCE',
            name: 'AYAS',
            description:
                'Forged around the idea of permanence, Ayas gives time an architectural, uncompromising presence.',
            footer: 'STEEL · ETERNAL'
        }
    ];

    _observer;

    renderedCallback() {
        if (this._observer) {
            return;
        }
        const section = this.template.querySelector('.collection-section');
        if (!section || typeof IntersectionObserver === 'undefined') {
            return;
        }
        // Content stays visible unless this runs, so a failure never hides the page.
        section.setAttribute('data-ready', 'true');
        this._observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.setAttribute('data-in', 'true');
                        this._observer.unobserve(entry.target);
                    }
                });
            },
            { threshold: 0.12 }
        );
        this.template.querySelectorAll('.reveal').forEach((el) => this._observer.observe(el));
    }

    disconnectedCallback() {
        if (this._observer) {
            this._observer.disconnect();
            this._observer = null;
        }
    }
}
