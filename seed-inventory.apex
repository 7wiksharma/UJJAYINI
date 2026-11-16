List<Product2> products = [
    SELECT Id, Name, ProductCode
    FROM Product2
    WHERE ProductCode IN ('UJ-CHR-001', 'UJ-HER-001')
];

Map<Id, Inventory__c> existingByProduct = new Map<Id, Inventory__c>();

for (Inventory__c inv : [
    SELECT Id, Product__c, On_Hand__c, Reserved__c, Inventory_Status__c
    FROM Inventory__c
    WHERE Product__c IN :products
]) {
    existingByProduct.put(inv.Product__c, inv);
}

List<Inventory__c> inventoriesToCreate = new List<Inventory__c>();

for (Product2 product : products) {

    if (!existingByProduct.containsKey(product.Id)) {
        inventoriesToCreate.add(
            new Inventory__c(
                Product__c = product.Id,
                On_Hand__c = 10,
                Reserved__c = 0,
                Inventory_Status__c = 'Active'
            )
        );
    }
}

if (!inventoriesToCreate.isEmpty()) {
    insert inventoriesToCreate;
}

System.debug('Inventory records created: ' + inventoriesToCreate.size());

for (Inventory__c inv : inventoriesToCreate) {
    System.debug(
        'Inventory = ' + inv.Id +
        ' | Product = ' + inv.Product__c +
        ' | On Hand = ' + inv.On_Hand__c +
        ' | Reserved = ' + inv.Reserved__c +
        ' | Status = ' + inv.Inventory_Status__c
    );
}
