import { LightningElement } from 'lwc';

import heroVideo
    from '@salesforce/resourceUrl/UJJAYINI_Product_Detail_Video';

export default class UjjayiniHero extends LightningElement {

    /**
     * UJJAYINI cinematic hero video.
     */
    get videoUrl() {
        return heroVideo;
    }


    /**
     * Current Ghaṭikā.
     *
     * 1 day = 60 ghaṭikā.
     */
    get ghatika() {

        const now = new Date();

        const hours = now.getHours();

        const minutes = now.getMinutes();

        const seconds = now.getSeconds();

        const totalSeconds =
            (hours * 3600) +
            (minutes * 60) +
            seconds;

        const totalDaySeconds =
            24 * 60 * 60;

        const value =
            (totalSeconds / totalDaySeconds) * 60;

        return Math.floor(value)
            .toString()
            .padStart(2, '0');
    }


    /**
     * Navigate to the Collections page.
     */
    handleExplore() {

        window.location.href =
            '/ujjayini/collections';
    }
}