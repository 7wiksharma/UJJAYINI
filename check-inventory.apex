List<Inventory__c> inv = [
    SELECT Id, Product__c, On_Hand__c, Reserved__c,
           Available__c, Inventory_Status__c
    FROM Inventory__c
];

System.debug('COUNT = ' + inv.size());

for (Inventory__c i : inv) {
    System.debug(
        'ID=' + i.Id +
        ' PRODUCT=' + i.Product__c +
        ' ON_HAND=' + i.On_Hand__c +
        ' RESERVED=' + i.Reserved__c +
        ' AVAILABLE=' + i.Available__c +
        ' STATUS=' + i.Inventory_Status__c
    );
}
