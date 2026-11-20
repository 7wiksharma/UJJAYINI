public without sharing class OrderInvoiceService {

    private static final String BRAND = 'UJJAYINI';


    // =========================================================
    // NAMES
    // =========================================================

    public static String invoiceNumber(Order orderRecord) {
        return 'UJ-INV-' + orderRecord.OrderNumber;
    }

    public static String creditNoteNumber(Order orderRecord) {
        return 'UJ-CN-' + orderRecord.OrderNumber;
    }

    public static String fileName(Order orderRecord) {
        return 'UJJAYINI-Invoice-' + orderRecord.OrderNumber + '.pdf';
    }


    // =========================================================
    // DATA
    // =========================================================

    public static Order loadOrder(Id orderId) {

        List<Order> orders = [
            SELECT Id,
                   OrderNumber,
                   Status,
                   AccountId,
                   EffectiveDate,
                   ActivatedDate,
                   TotalAmount,
                   Is_Cancelled__c,
                   Cancelled_At__c,
                   Invoice_Emailed_At__c,
                   BillToContactId,
                   ShipToContactId,
                   ShippingStreet,
                   ShippingCity,
                   ShippingState,
                   ShippingPostalCode,
                   ShippingCountry,
                   BillingStreet,
                   BillingCity,
                   BillingState,
                   BillingPostalCode,
                   BillingCountry
            FROM Order
            WHERE Id = :orderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order not found.');
        }

        return orders[0];
    }


    private static List<OrderItem> loadItems(Id orderId) {

        return [
            SELECT Id,
                   Quantity,
                   UnitPrice,
                   TotalPrice,
                   Product2.Name,
                   Product2.ProductCode
            FROM OrderItem
            WHERE OrderId = :orderId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];
    }


    private static Payment__c latestPayment(Id orderId) {

        List<Payment__c> payments = [
            SELECT Id,
                   Name,
                   Amount__c,
                   Payment_Status__c,
                   Gateway_Payment_ID__c,
                   Paid_At__c,
                   Refunded_At__c
            FROM Payment__c
            WHERE Order__c = :orderId
            WITH SYSTEM_MODE
            ORDER BY Paid_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 1
        ];

        return payments.isEmpty() ? null : payments[0];
    }


    private static Contact findCustomer(Order orderRecord) {

        Id contactId =
            orderRecord.BillToContactId != null
                ? orderRecord.BillToContactId
                : orderRecord.ShipToContactId;

        if (contactId != null) {

            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone
                FROM Contact
                WHERE Id = :contactId
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            if (!contacts.isEmpty()) {
                return contacts[0];
            }
        }

        List<Contact> fallback = [
            SELECT Id, Name, Email, Phone
            FROM Contact
            WHERE AccountId = :orderRecord.AccountId
            AND Email != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        return fallback.isEmpty() ? null : fallback[0];
    }


    // =========================================================
    // PDF
    // =========================================================

    public static Blob buildInvoicePdf(Id orderId) {

        return Blob.toPdf(
            buildInvoiceHtml(orderId)
        );
    }


    public static String buildInvoiceHtml(Id orderId) {

        Order orderRecord = loadOrder(orderId);
        List<OrderItem> items = loadItems(orderId);
        Payment__c payment = latestPayment(orderId);
        Contact customer = findCustomer(orderRecord);

        Boolean isCancelled = orderRecord.Is_Cancelled__c == true;

        List<String> html = new List<String>();

        html.add('<html><head><style>');
        html.add('@page { size: A4; margin: 18mm 16mm; }');
        html.add('body { font-family: Helvetica, Arial, sans-serif; color: #1c1a17; font-size: 9.5pt; }');
        html.add('table { width: 100%; border-collapse: collapse; }');
        html.add('.brand { font-family: "Times New Roman", serif; font-size: 24pt; letter-spacing: 7pt; }');
        html.add('.tag { color: #a8822f; font-size: 6.5pt; letter-spacing: 3pt; }');
        html.add('.doc { font-family: "Times New Roman", serif; font-size: 18pt; letter-spacing: 4pt; text-align: right; }');
        html.add('.muted { color: #6e6352; }');
        html.add('.label { font-size: 6.5pt; letter-spacing: 2pt; color: #a8822f; padding-bottom: 4px; }');
        html.add('.rule { border-top: 1px solid #c9a24d; margin: 14px 0; }');
        html.add('.items th { text-align: left; font-size: 6.5pt; letter-spacing: 2pt; color: #a8822f; border-bottom: 1px solid #c9a24d; padding: 6px 4px; }');
        html.add('.items td { padding: 9px 4px; border-bottom: 1px solid #e6dcc6; vertical-align: top; }');
        html.add('.right { text-align: right; }');
        html.add('.total td { padding-top: 12px; font-size: 12pt; }');
        html.add('.stamp { border: 2px solid #b3322d; color: #b3322d; padding: 8px; text-align: center; letter-spacing: 3pt; font-weight: bold; margin-top: 14px; }');
        html.add('.credit { border-left: 2px solid #b3322d; padding: 8px 12px; margin-top: 12px; }');
        html.add('.footer { margin-top: 28px; font-size: 7.5pt; text-align: center; color: #6e6352; }');
        html.add('</style></head><body>');

        // Header
        html.add('<table><tr><td>');
        html.add('<div class="brand">' + BRAND + '</div>');
        html.add('<div class="tag">THE BEGINNING OF YOUR TIME</div>');
        html.add('</td><td>');
        html.add('<div class="doc">INVOICE</div>');
        html.add('<div class="right muted">' + esc(invoiceNumber(orderRecord)) + '</div>');
        html.add('<div class="right muted">Date: ' + esc(formatDate(invoiceDate(orderRecord))) + '</div>');
        html.add('</td></tr></table>');

        html.add('<div class="rule"></div>');

        // Parties
        html.add('<table><tr>');
        html.add('<td width="50%" style="vertical-align: top;">');
        html.add('<div class="label">BILLED TO</div>');
        html.add('<div>' + esc(customer != null ? customer.Name : '') + '</div>');
        html.add(addressHtml(
            orderRecord.BillingStreet,
            orderRecord.BillingCity,
            orderRecord.BillingState,
            orderRecord.BillingPostalCode,
            orderRecord.BillingCountry
        ));
        if (customer != null && String.isNotBlank(customer.Email)) {
            html.add('<div class="muted">' + esc(customer.Email) + '</div>');
        }
        if (customer != null && String.isNotBlank(customer.Phone)) {
            html.add('<div class="muted">' + esc(customer.Phone) + '</div>');
        }
        html.add('</td>');
        html.add('<td width="50%" style="vertical-align: top;">');
        html.add('<div class="label">SHIPPED TO</div>');
        html.add('<div>' + esc(customer != null ? customer.Name : '') + '</div>');
        html.add(addressHtml(
            orderRecord.ShippingStreet,
            orderRecord.ShippingCity,
            orderRecord.ShippingState,
            orderRecord.ShippingPostalCode,
            orderRecord.ShippingCountry
        ));
        html.add('</td>');
        html.add('</tr></table>');

        html.add('<div class="rule"></div>');

        // Items
        html.add('<table class="items">');
        html.add('<tr><th>TIMEPIECE</th><th>REFERENCE</th><th class="right">QTY</th><th class="right">UNIT PRICE</th><th class="right">AMOUNT</th></tr>');

        for (OrderItem item : items) {

            html.add('<tr>');
            html.add('<td>' + esc(item.Product2 != null ? item.Product2.Name : 'UJJAYINI Timepiece') + '</td>');
            html.add('<td class="muted">' + esc(item.Product2 != null ? item.Product2.ProductCode : '') + '</td>');
            html.add('<td class="right">' + String.valueOf(item.Quantity == null ? 0 : item.Quantity.intValue()) + '</td>');
            html.add('<td class="right">' + esc(formatInr(item.UnitPrice)) + '</td>');
            html.add('<td class="right">' + esc(formatInr(item.TotalPrice)) + '</td>');
            html.add('</tr>');
        }

        html.add('<tr class="total"><td colspan="4" class="right">TOTAL</td>');
        html.add('<td class="right"><b>' + esc(formatInr(orderRecord.TotalAmount)) + '</b></td></tr>');
        html.add('</table>');

        // Payment
        html.add('<div class="rule"></div>');
        html.add('<div class="label">PAYMENT</div>');

        if (payment != null) {

            html.add('<div>Paid via Razorpay');

            if (payment.Paid_At__c != null) {
                html.add(' on ' + esc(formatDate(payment.Paid_At__c.date())));
            }

            html.add('</div>');

            if (String.isNotBlank(payment.Gateway_Payment_ID__c)) {
                html.add('<div class="muted">Transaction: ' + esc(payment.Gateway_Payment_ID__c) + '</div>');
            }

        } else {

            html.add('<div class="muted">Payment details are not available.</div>');
        }

        // Cancellation / credit note
        if (isCancelled) {

            html.add('<div class="stamp">CANCELLED &#183; REFUNDED</div>');

            html.add('<div class="credit">');
            html.add('<div class="label">CREDIT NOTE ' + esc(creditNoteNumber(orderRecord)) + '</div>');

            String refundDate =
                payment != null && payment.Refunded_At__c != null
                    ? formatDate(payment.Refunded_At__c.date())
                    : formatDate(
                        orderRecord.Cancelled_At__c != null
                            ? orderRecord.Cancelled_At__c.date()
                            : Date.today()
                    );

            html.add(
                '<div>This order was cancelled. A refund of ' +
                esc(formatInr(orderRecord.TotalAmount)) +
                ' was issued on ' + esc(refundDate) +
                ' to the original payment method.</div>'
            );

            html.add('</div>');
        }

        // Footer
        html.add('<div class="footer">');
        html.add('Thank you for choosing ' + BRAND + '. Time is not simply measured. It is remembered.<br/>');
        html.add('This is a computer-generated document and does not require a signature.');
        html.add('</div>');

        html.add('</body></html>');

        return String.join(html, '');
    }


    // =========================================================
    // EMAILS (never throw from the "Safely" versions)
    // =========================================================

    public static void sendInvoiceEmailSafely(Id orderId) {

        try {

            sendInvoiceEmail(orderId);

        } catch (Exception e) {

            System.debug(
                LoggingLevel.ERROR,
                'UJJAYINI invoice email failed: ' + e.getMessage()
            );
        }
    }


    /*
     * Sends the invoice once per order. Returns true when sent.
     */
    public static Boolean sendInvoiceEmail(Id orderId) {

        Order orderRecord = loadOrder(orderId);

        if (
            orderRecord.Status != 'Activated' ||
            orderRecord.Is_Cancelled__c == true ||
            orderRecord.Invoice_Emailed_At__c != null
        ) {
            return false;
        }

        Contact customer = findCustomer(orderRecord);

        if (customer == null || String.isBlank(customer.Email)) {
            return false;
        }

        sendWithPdf(
            orderRecord,
            customer,
            'Your ' + BRAND + ' timepiece is confirmed',
            'Thank you for your acquisition.',
            'Your payment has been received and your timepiece is ' +
            'being prepared. Your invoice is attached, and your ' +
            'timepiece now appears in your Collector&#39;s Vault.'
        );

        Database.update(
            new Order(
                Id = orderRecord.Id,
                Invoice_Emailed_At__c = System.now()
            ),
            AccessLevel.SYSTEM_MODE
        );

        return true;
    }


    public static void sendCancellationEmailSafely(Id orderId) {

        try {

            Order orderRecord = loadOrder(orderId);

            Contact customer = findCustomer(orderRecord);

            if (customer == null || String.isBlank(customer.Email)) {
                return;
            }

            sendWithPdf(
                orderRecord,
                customer,
                'Your ' + BRAND + ' order has been cancelled',
                'Your order has been cancelled.',
                'As requested, your order has been cancelled and a ' +
                'refund has been started to your original payment ' +
                'method. The attached document includes your credit note.'
            );

        } catch (Exception e) {

            System.debug(
                LoggingLevel.ERROR,
                'UJJAYINI cancellation email failed: ' + e.getMessage()
            );
        }
    }


    private static void sendWithPdf(
        Order orderRecord,
        Contact customer,
        String subject,
        String heading,
        String message
    ) {

        Blob pdf = buildInvoicePdf(orderRecord.Id);

        Messaging.EmailFileAttachment attachment =
            new Messaging.EmailFileAttachment();

        attachment.setFileName(fileName(orderRecord));
        attachment.setContentType('application/pdf');
        attachment.setBody(pdf);

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setToAddresses(new List<String>{ customer.Email });
        mail.setSenderDisplayName(BRAND);
        mail.setSubject(subject);
        mail.setSaveAsActivity(false);

        mail.setHtmlBody(
            '<div style="background:#05060a;padding:40px 24px;font-family:Helvetica,Arial,sans-serif;">' +
            '<div style="max-width:560px;margin:0 auto;color:#f3ead7;">' +
            '<div style="font-family:Georgia,serif;font-size:26px;letter-spacing:8px;">' + BRAND + '</div>' +
            '<div style="color:#c9a24d;font-size:9px;letter-spacing:4px;margin-top:6px;">THE BEGINNING OF YOUR TIME</div>' +
            '<div style="height:1px;background:#c9a24d;margin:24px 0;"></div>' +
            '<div style="font-family:Georgia,serif;font-size:24px;">' + esc(heading) + '</div>' +
            '<p style="font-size:14px;line-height:1.8;color:#d9cfbc;">Dear ' + esc(customer.Name) + ',</p>' +
            '<p style="font-size:14px;line-height:1.8;color:#d9cfbc;">' + message + '</p>' +
            '<p style="font-size:14px;line-height:1.8;color:#d9cfbc;">Total: ' + esc(formatInr(orderRecord.TotalAmount)) + '</p>' +
            '<div style="height:1px;background:#c9a24d;margin:24px 0;"></div>' +
            '<div style="font-size:11px;color:#8f8573;">Time is not simply measured. It is remembered.</div>' +
            '</div></div>'
        );

        mail.setFileAttachments(
            new List<Messaging.EmailFileAttachment>{ attachment }
        );

        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ mail }
        );
    }


    // =========================================================
    // FORMATTING
    // =========================================================

    private static Date invoiceDate(Order orderRecord) {

        if (orderRecord.ActivatedDate != null) {
            return orderRecord.ActivatedDate.date();
        }

        return orderRecord.EffectiveDate != null
            ? orderRecord.EffectiveDate
            : Date.today();
    }


    private static String addressHtml(
        String street,
        String city,
        String state,
        String postalCode,
        String country
    ) {

        if (String.isBlank(street) && String.isBlank(city)) {
            return '<div class="muted">Address not recorded</div>';
        }

        List<String> lines = new List<String>();

        if (String.isNotBlank(street)) {
            for (String line : street.replace('\r\n', '\n').split('\n')) {
                if (String.isNotBlank(line)) {
                    lines.add(esc(line.trim()));
                }
            }
        }

        List<String> cityParts = new List<String>();

        if (String.isNotBlank(city)) { cityParts.add(city); }
        if (String.isNotBlank(state)) { cityParts.add(state); }
        if (String.isNotBlank(postalCode)) { cityParts.add(postalCode); }

        if (!cityParts.isEmpty()) {
            lines.add(esc(String.join(cityParts, ', ')));
        }

        if (String.isNotBlank(country)) {
            lines.add(esc(country));
        }

        return '<div class="muted">' + String.join(lines, '<br/>') + '</div>';
    }


    private static String formatDate(Date value) {

        if (value == null) {
            return '';
        }

        return Datetime.newInstance(
            value,
            Time.newInstance(12, 0, 0, 0)
        ).format('dd MMM yyyy');
    }


      @TestVisible
    private static String formatInr(Decimal amount) {

        Decimal value =
            amount == null
                ? 0
                : amount.setScale(2, RoundingMode.HALF_UP);

        Boolean negative = value < 0;

        String plain = value.abs().toPlainString();

        String whole = plain.contains('.') ? plain.substringBefore('.') : plain;
        String fraction = plain.contains('.') ? plain.substringAfter('.') : '00';

        String grouped = whole;

        if (whole.length() > 3) {

            // Indian grouping: last three digits, then pairs.
            // 165000 -> 1,65,000    1234567 -> 12,34,567
            String lastThree = whole.right(3);
            String rest = whole.left(whole.length() - 3);
            String pairs = '';

            while (rest.length() > 2) {
                pairs = ',' + rest.right(2) + pairs;
                rest = rest.left(rest.length() - 2);
            }

            grouped = rest + pairs + ',' + lastThree;
        }

        return (negative ? '-' : '') +
            'INR ' + grouped + '.' + fraction.rightPad(2, '0').left(2);
    }


    private static String esc(String value) {

        return value == null
            ? ''
            : value.escapeHtml4();
    }
}