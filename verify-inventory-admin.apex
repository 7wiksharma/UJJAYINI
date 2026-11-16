List<Inventory__c> inventoryRecords = [
    SELECT Id,
           Product__c,
           Product__r.Name,
           On_Hand__c,
           Reserved__c,
           Available__c,
           Inventory_Status__c
    FROM Inventory__c
    WHERE Product__c IN (
        SELECT Id
        FROM Product2
        WHERE ProductCode IN ('UJ-CHR-001', 'UJ-HER-001')
    )
];

System.debug('INVENTORY COUNT = ' + inventoryRecords.size());

for (Inventory__c inv : inventoryRecords) {
    System.debug(
        'Inventory=' + inv.Id +
        ' | Product=' + inv.Product__r.Name +
        ' | OnHand=' + inv.On_Hand__c +
        ' | Reserved=' + inv.Reserved__c +
        ' | Available=' + inv.Available__c +
        ' | Status=' + inv.Inventory_Status__c
    );
}
