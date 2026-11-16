import { LightningElement } from 'lwc';

export default class UjjayiniMeasureSection extends LightningElement {
    observer;

    renderedCallback() {
        if (this.observer) {
            return;
        }

        const elements = this.template.querySelectorAll(
            '.reveal, .reveal-card'
        );

        if (!elements.length) {
            return;
        }

        if (
            typeof IntersectionObserver === 'undefined'
        ) {
            elements.forEach((element) => {
                element.classList.add('is-visible');
            });

            return;
        }

        this.observer = new IntersectionObserver(
            (entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('is-visible');

                        this.observer.unobserve(
                            entry.target
                        );
                    }
                });
            },
            {
                threshold: 0.12,
                rootMargin: '0px 0px -8% 0px'
            }
        );

        elements.forEach((element) => {
            this.observer.observe(element);
        });
    }

    disconnectedCallback() {
        if (this.observer) {
            this.observer.disconnect();
            this.observer = undefined;
        }
    }
}