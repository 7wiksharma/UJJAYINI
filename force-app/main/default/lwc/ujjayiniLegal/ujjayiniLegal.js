import { LightningElement, api } from 'lwc';


const PRIVACY = {
    eyebrow: 'PRIVACY POLICY',
    title: 'Your privacy,',
    accent: 'kept with care.',
    updated: '20 November 2026',
    intro:
        'This policy explains what personal information the House of UJJAYINI ' +
        'collects when you use this website, why we collect it, and the choices you have.',
    sections: [
        {
            id: 'collect',
            heading: 'Information we collect',
            paragraphs: [
                'Account details: your name, email address, phone number and password (stored securely by our platform; we never see it).',
                'Order details: the timepieces you purchase, delivery and billing addresses, and order history.',
                'Ownership and care: your registered timepieces, warranties and service requests.',
                'Enquiries: messages you send through the Concierge form.'
            ]
        },
        {
            id: 'use',
            heading: 'How we use it',
            paragraphs: [
                'To create and manage your account, process and deliver your orders, issue invoices and refunds, register warranties and handle service requests.',
                'To reply to your enquiries and, with your agreement, to tell you about new collections.',
                'To keep the website secure and to prevent fraud.'
            ]
        },
        {
            id: 'payments',
            heading: 'Payments',
            paragraphs: [
                'Payments are processed by Razorpay. Your card and bank details are entered on Razorpay\'s secure page and are not stored by UJJAYINI. We keep only a payment reference and its status.'
            ]
        },
        {
            id: 'sharing',
            heading: 'Who we share it with',
            paragraphs: [
                'Our service providers, only as needed to run the website and fulfil orders: the platform that hosts this website and our data (Salesforce), our payment partner (Razorpay) and our delivery partners.',
                'We do not sell your personal information.'
            ]
        },
        {
            id: 'retention',
            heading: 'How long we keep it',
            paragraphs: [
                'We keep your information while your account is active and afterwards for as long as needed for warranty, service, accounting and legal obligations.'
            ]
        },
        {
            id: 'rights',
            heading: 'Your choices and rights',
            paragraphs: [
                'You can view and update your phone number and address in My Account.',
                'You may ask us to access, correct or delete your personal information, subject to the law that applies to us in India, including the Digital Personal Data Protection Act, 2023.'
            ]
        },
        {
            id: 'cookies',
            heading: 'Cookies',
            paragraphs: [
                'The website uses essential cookies to keep you signed in and to remember your cart. They are needed for the website to work.'
            ]
        },
        {
            id: 'contact',
            heading: 'Contact us',
            paragraphs: [
                '[Company legal name], [Registered address]. Email: [privacy contact email].',
                'You can also reach us through the Concierge form at the foot of every page.'
            ]
        }
    ]
};


const TERMS = {
    eyebrow: 'TERMS OF USE',
    title: 'The terms of',
    accent: 'our house.',
    updated: '20 November 2026',
    intro:
        'These terms apply when you use this website and when you buy from the ' +
        'House of UJJAYINI. By creating an account or placing an order, you accept them.',
    sections: [
        {
            id: 'account',
            heading: 'Your account',
            paragraphs: [
                'You must give accurate details and keep your password private. You are responsible for activity on your account.'
            ]
        },
        {
            id: 'orders',
            heading: 'Orders and prices',
            paragraphs: [
                'Prices are shown in Indian Rupees (INR). An order is confirmed only after your payment is received.',
                'When you proceed to payment, the timepieces in your cart are held for a short time. If payment is not completed, they are released.',
                'All timepieces are subject to availability. If we cannot fulfil an order, we will refund you in full.'
            ]
        },
        {
            id: 'payment',
            heading: 'Payment',
            paragraphs: [
                'Payments are made through Razorpay. Your order is placed once Razorpay confirms the payment.'
            ]
        },
        {
            id: 'cancellation',
            heading: 'Cancellation and refunds',
            paragraphs: [
                'You may cancel an order from your order page while it is being processed or packed, and before it is shipped.',
                'Refunds are returned to your original payment method. The time the refund takes to appear depends on your bank or card issuer.',
                'Once an order has been shipped it can no longer be cancelled online; please contact UJJAYINI Service.'
            ]
        },
        {
            id: 'delivery',
            heading: 'Delivery',
            paragraphs: [
                'We deliver to the address you give at checkout. You can follow your order\'s progress on its order page.'
            ]
        },
        {
            id: 'warranty',
            heading: 'Warranty and service',
            paragraphs: [
                'Each timepiece comes with a standard warranty of 24 months from purchase, shown in your Collector\'s Vault. The warranty does not cover damage from accidents, misuse or unauthorised repair.',
                'Service and repair requests can be made from the Service page.'
            ]
        },
        {
            id: 'ip',
            heading: 'Our name and content',
            paragraphs: [
                'The UJJAYINI name, designs, images and text on this website belong to [Company legal name] and may not be used without our written permission.'
            ]
        },
        {
            id: 'liability',
            heading: 'Our responsibility',
            paragraphs: [
                'Nothing in these terms limits rights you have under Indian consumer law. Beyond those rights, our responsibility for any order is limited to the amount you paid for it.'
            ]
        },
        {
            id: 'law',
            heading: 'Governing law',
            paragraphs: [
                'These terms are governed by the laws of India. Disputes are subject to the courts of [City], India.'
            ]
        },
        {
            id: 'changes',
            heading: 'Changes and contact',
            paragraphs: [
                'We may update these terms; the date at the top shows the latest version.',
                '[Company legal name], [Registered address]. Email: [contact email].'
            ]
        }
    ]
};


export default class UjjayiniLegal extends LightningElement {

    // Set in Experience Builder: Privacy or Terms
    @api documentType = 'Privacy';

    get doc() {
        return (this.documentType || '').toLowerCase() === 'terms' ? TERMS : PRIVACY;
    }

    get sections() {

        return this.doc.sections.map((section, index) => ({
            ...section,
            number: String(index + 1).padStart(2, '0'),
            anchorClass: 'toc-link',
            paragraphs: section.paragraphs.map((text, i) => ({ key: section.id + i, text }))
        }));
    }

    scrollToSection(event) {

        const target = this.template.querySelector(
            '[data-section="' + event.currentTarget.dataset.id + '"]'
        );

        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }
}