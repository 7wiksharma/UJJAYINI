import { LightningElement } from 'lwc';
import isGuest from '@salesforce/user/isGuest';
import vaultVisual from '@salesforce/resourceUrl/UJJAYINI_Vault_Teaser_Visual';

export default class UjjayiniVaultTeaser extends LightningElement {

    get vaultVisualStyle() {
        return `background-image: url("${vaultVisual}");`;
    }

    handleEnterVault() {

        const vaultPath =
            '/ujjayini/collector-vault';

        if (isGuest) {

            const loginUrl =
                '/ujjayini/login?startURL=' +
                encodeURIComponent(vaultPath);

            window.location.assign(loginUrl);

            return;
        }

        window.location.assign(vaultPath);
    }

}