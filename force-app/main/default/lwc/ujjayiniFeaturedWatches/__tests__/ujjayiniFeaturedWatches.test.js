import { createElement } from '@lwc/engine-dom';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import UjjayiniFeaturedWatches from 'c/ujjayiniFeaturedWatches';
import getFeaturedWatches from '@salesforce/apex/UJJAYINIFeaturedWatchesController.getFeaturedWatches';

const getFeaturedWatchesAdapter = registerApexTestWireAdapter(getFeaturedWatches);

describe('c-ujjayini-featured-watches', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders editorial watch details without displaying internal identifiers', async () => {
        const element = createElement('c-ujjayini-featured-watches', {
            is: UjjayiniFeaturedWatches
        });
        document.body.appendChild(element);

        getFeaturedWatchesAdapter.emit([{
            productId: 'A00BM00003QRMXFAAR',
            productCode: 'INTERNAL-SKU-001',
            modelNumber: 'INTERNAL-MODEL-001',
            name: 'Hiranya Swarna-Ryu Dragon',
            collection: 'Hiranya',
            movement: 'Automatic',
            caseMaterial: 'Rose Gold',
            imageUrl: 'https://example.com/watch.png'
        }]);

        await Promise.resolve();

        const card = element.shadowRoot.querySelector('.watch-card');
        expect(card.textContent).toContain('Hiranya Swarna-Ryu Dragon');
        expect(card.textContent).toContain('Automatic · Rose Gold');
        expect(card.textContent).not.toContain('A00BM00003QRMXFAAR');
        expect(card.textContent).not.toContain('INTERNAL-SKU-001');
        expect(card.textContent).not.toContain('INTERNAL-MODEL-001');
        expect(card.querySelector('[data-id="A00BM00003QRMXFAAR"]')).not.toBeNull();
    });
});
