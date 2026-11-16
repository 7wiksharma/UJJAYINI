RazorpayPaymentLinkService.PaymentLinkRequest request =
    new RazorpayPaymentLinkService.PaymentLinkRequest();

request.orderId = '801bm00003HCTNuAAP';

RazorpayPaymentLinkService.PaymentLinkResult result =
    RazorpayPaymentLinkService.createPaymentLink(request);

System.debug('===== UJJAYINI PAYMENT LINK TEST =====');
System.debug('ORDER ID: ' + result.orderId);
System.debug('PAYMENT ID: ' + result.paymentId);
System.debug('PAYMENT LINK ID: ' + result.paymentLinkId);
System.debug('PAYMENT URL: ' + result.paymentUrl);
System.debug('AMOUNT: ' + result.amount);
System.debug('STATUS: ' + result.status);
