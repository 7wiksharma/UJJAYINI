import { LightningElement } from 'lwc';

import CRAFT_VIDEO
    from '@salesforce/resourceUrl/UJJAYINI_Craftsmanship_Video';

export default class UjjayiniCraftsmanship extends LightningElement {

    videoUrl = CRAFT_VIDEO;

    craftPoints = [
        {
            id: 'case',
            number: '01',
            category: 'THE CASE',
            title: 'Form',
            description:
                'Every case begins with proportion. Curves, edges and surfaces are refined until the silhouette feels inevitable.'
        },
        {
            id: 'dial',
            number: '02',
            category: 'THE DIAL',
            title: 'Depth',
            description:
                'Layer by layer, the dial creates a quiet sense of depth where light changes with every movement of the wrist.'
        },
        {
            id: 'movement',
            number: '03',
            category: 'THE MOVEMENT',
            title: 'Precision',
            description:
                'At the heart of every timepiece lies a disciplined relationship between mechanical movement and measured time.'
        },
        {
            id: 'finish',
            number: '04',
            category: 'THE FINISH',
            title: 'Character',
            description:
                'Polishing, brushing and finishing give each surface its final character — subtle enough to discover, impossible to ignore.'
        }
    ];

}