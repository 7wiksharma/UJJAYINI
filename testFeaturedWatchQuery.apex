List<Product2> products = [
    SELECT
        Id,
        Name,
        Model_Number__c,
        Product_Image_URL__c
    FROM Product2
    WHERE IsActive = true
    AND Product_Image_URL__c != null
    LIMIT 3
];

System.debug('PRODUCT COUNT = ' + products.size());

for (Product2 p : products) {
    System.debug(
        'PRODUCT = ' +
        p.Name +
        ' | MODEL = ' +
        p.Model_Number__c
    );
}
