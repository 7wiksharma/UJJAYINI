import { LightningElement, api } from 'lwc';

export default class UjjayiniSpacer extends LightningElement {

    // Height in pixels (room for the floating header).
    @api height = 140;

    // Background colour of the spacer.
    @api background = '#05060a';

    get spacerStyle() {

        const height = Number(this.height) > 0 ? Number(this.height) : 140;

        return 'height: ' + height + 'px; background: ' +
            (this.background || '#05060a') + ';';
    }
}