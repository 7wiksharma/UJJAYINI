import { createElement } from '@lwc/engine-dom';
import UjjayiniHomeExperience from 'c/ujjayiniHomeExperience';

describe('c-ujjayini-home-experience', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the editorial home sections and collection route', () => {
        const element = createElement('c-ujjayini-home-experience', {
            is: UjjayiniHomeExperience
        });

        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('h1').textContent.trim()).toBe('UJJAYINI');
        expect(element.shadowRoot.querySelector('.origin h2').textContent).toContain('Before the clock');
        expect(element.shadowRoot.querySelector('.vault')).not.toBeNull();
        expect(element.shadowRoot.querySelector('.hero .cta').getAttribute('href')).toBe('/ujjayini/collections');
        expect(element.shadowRoot.querySelector('c-ujjayini-site-footer')).toBeNull();
    });
});
