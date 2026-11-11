// ============================================
// UJJAYINI CATALOG SEED DATA
// Safe to run multiple times
// ============================================

// --------------------------------------------
// 1. Get or create Collection
// --------------------------------------------

Collection__c collectionRecord;

List<Collection__c> existingCollections = [
    SELECT Id, Name
    FROM Collection__c
    WHERE Name = 'UJJAYINI Signature Collection'
    LIMIT 1
];

if (!existingCollections.isEmpty()) {

    collectionRecord = existingCollections[0];

} else {

    collectionRecord = new Collection__c(
        Name = 'UJJAYINI Signature Collection'
    );

    insert collectionRecord;
}


// --------------------------------------------
// 2. Get or create Watch 1
// --------------------------------------------

Product2 watch1;

List<Product2> existingWatch1 = [
    SELECT Id, Name, ProductCode
    FROM Product2
    WHERE ProductCode = 'UJ-CHR-001'
    LIMIT 1
];

if (!existingWatch1.isEmpty()) {

    watch1 = existingWatch1[0];

} else {

    watch1 = new Product2(
        Name = 'UJJAYINI Chronograph',
        ProductCode = 'UJ-CHR-001',
        Description = 'Premium automatic chronograph watch.',
        Family = 'Watches',
        Collection__c = collectionRecord.Id,
        IsActive = true
    );

    insert watch1;
}


// --------------------------------------------
// 3. Get or create Watch 2
// --------------------------------------------

Product2 watch2;

List<Product2> existingWatch2 = [
    SELECT Id, Name, ProductCode
    FROM Product2
    WHERE ProductCode = 'UJ-HER-001'
    LIMIT 1
];

if (!existingWatch2.isEmpty()) {

    watch2 = existingWatch2[0];

} else {

    watch2 = new Product2(
        Name = 'UJJAYINI Heritage',
        ProductCode = 'UJ-HER-001',
        Description = 'Classic heritage timepiece with a refined design.',
        Family = 'Watches',
        Collection__c = collectionRecord.Id,
        IsActive = true
    );

    insert watch2;
}


// --------------------------------------------
// 4. Get Standard Pricebook
// --------------------------------------------

Pricebook2 standardPricebook = [
    SELECT Id,
           Name,
           IsActive,
           IsStandard
    FROM Pricebook2
    WHERE IsStandard = true
    LIMIT 1
];


// Make sure Standard Pricebook is active

if (!standardPricebook.IsActive) {

    standardPricebook.IsActive = true;

    update standardPricebook;
}


// --------------------------------------------
// 5. Check existing Pricebook Entries
// --------------------------------------------

Map<Id, PricebookEntry> existingEntriesByProduct =
    new Map<Id, PricebookEntry>();

for (PricebookEntry entry : [
    SELECT Id,
           Product2Id,
           UnitPrice,
           IsActive
    FROM PricebookEntry
    WHERE Pricebook2Id = :standardPricebook.Id
    AND Product2Id IN :new Set<Id>{
        watch1.Id,
        watch2.Id
    }
]) {

    existingEntriesByProduct.put(
        entry.Product2Id,
        entry
    );
}


// --------------------------------------------
// 6. Create / update Watch 1 Price
// --------------------------------------------

List<PricebookEntry> entriesToInsert =
    new List<PricebookEntry>();

List<PricebookEntry> entriesToUpdate =
    new List<PricebookEntry>();


if (existingEntriesByProduct.containsKey(watch1.Id)) {

    PricebookEntry entry =
        existingEntriesByProduct.get(watch1.Id);

    entry.UnitPrice = 49999;
    entry.IsActive = true;

    entriesToUpdate.add(entry);

} else {

    entriesToInsert.add(
        new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = watch1.Id,
            UnitPrice = 49999,
            IsActive = true
        )
    );
}


// --------------------------------------------
// 7. Create / update Watch 2 Price
// --------------------------------------------

if (existingEntriesByProduct.containsKey(watch2.Id)) {

    PricebookEntry entry =
        existingEntriesByProduct.get(watch2.Id);

    entry.UnitPrice = 69999;
    entry.IsActive = true;

    entriesToUpdate.add(entry);

} else {

    entriesToInsert.add(
        new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = watch2.Id,
            UnitPrice = 69999,
            IsActive = true
        )
    );
}


// --------------------------------------------
// 8. Save Pricebook Entries
// --------------------------------------------

if (!entriesToInsert.isEmpty()) {
    insert entriesToInsert;
}

if (!entriesToUpdate.isEmpty()) {
    update entriesToUpdate;
}


// --------------------------------------------
// 9. Output
// --------------------------------------------

System.debug('======================================');
System.debug('UJJAYINI CATALOG READY');
System.debug('======================================');

System.debug(
    'Collection: ' +
    collectionRecord.Id +
    ' | ' +
    collectionRecord.Name
);

System.debug(
    'Watch 1: ' +
    watch1.Id +
    ' | ' +
    watch1.Name +
    ' | ₹49,999'
);

System.debug(
    'Watch 2: ' +
    watch2.Id +
    ' | ' +
    watch2.Name +
    ' | ₹69,999'
);

System.debug(
    'Standard Pricebook: ' +
    standardPricebook.Id
);

System.debug('======================================');