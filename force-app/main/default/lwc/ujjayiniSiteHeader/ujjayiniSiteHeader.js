import { LightningElement } from 'lwc';

export default class UjjayiniSiteHeader extends LightningElement {

    menuOpen = false;

    toggleMenu() {
        this.menuOpen = !this.menuOpen;
    }

    closeMenu() {
        this.menuOpen = false;
    }

}