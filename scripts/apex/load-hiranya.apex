/*
 * UJJAYINI - load / refresh the HIRANYA collection watches
 * ----------------------------------------------------------
 * One row in WATCHES = one watch (its own image, name, specs, price, stock).
 * Edit any row freely: picklist values are matched to the org's real
 * active values, so a slightly different word never breaks the insert.
 *
 * Re-runnable: rows are keyed by ProductCode (UJB-HIR-1xx).
 *   - code already exists -> the product, its price and image are UPDATED
 *   - code is new         -> Product2 + Standard PricebookEntry + Inventory__c are CREATED
 *   (existing Inventory rows are never touched, so real stock is safe)
 *
 * Run:
 *   1) DRY_RUN = true  -> sf apex run --file scripts/apex/load-hiranya.apex
 *   2) DRY_RUN = false -> run again to save
 */

Boolean DRY_RUN = false;

String COLLECTION_MATCH = '%Hiran%';   // finds "Hiranya"
String CODE_PREFIX      = 'UJB-HIR-';

/*
 * code no | name | image | dial | case | strap | movement | water | limited | edition size | warranty months | price INR | stock | story
 */
List<List<Object>> WATCHES = new List<List<Object>>{
    new List<Object>{ 101, 'Dragon Phoenix Tourbillon',
        'https://res.cloudinary.com/pk7hvj1x/image/upload/v1795369155/Ornate_Gold_Dragon_Phoenix_Tourbillon_Watch.png',
        'Golden', 'Yellow Gold', 'Gold', 'Manual', '30 m (3 ATM)', true, 7, 36, 1250000, 1,
        'A dragon and a phoenix hand-engraved in gold, circling a tourbillon that never rests.' },

    new List<Object>{ 102, 'Suvarna Surya Automatic',
        'https://res.cloudinary.com/pk7hvj1x/image/upload/v1795368654/Gemini_Generated_Image_uj8dpxuj8dpxuj8d.png',
        'Golden Sunburst', 'Yellow Gold', 'Leather', 'Automatic', '50 m (5 ATM)', false, null, 36, 465000, 6,
        'A sunburst dial that catches the first light, like the sun rising over the Shipra.' },

    new List<Object>{ 103, 'Hiranya Swarna Dress 38',
        'https://res.cloudinary.com/pk7hvj1x/image/upload/v1795368524/Gemini_Generated_Image_w7isb8w7isb8w7is.png',
        'Champagne', 'Yellow Gold', 'Leather', 'Manual', '30 m (3 ATM)', false, null, 24, 385000, 5,
        'A slim 38 mm dress watch in pure gold, made for evenings that matter.' },

    new List<Object>{ 104, 'Kanak Royal Chronograph',
        'https://res.cloudinary.com/pk7hvj1x/image/upload/v1795368377/Gemini_Generated_Image_xj36b3xj36b3xj36.png',
        'Golden', 'Yellow Gold', 'Gold', 'Automatic', '100 m (10 ATM)', true, 20, 36, 695000, 2,
        'A full gold chronograph with the presence of a royal court.' },

    new List<Object>{ 105, 'Vighnaharta Rose Gold',
        'https://res.cloudinary.com/pk7hvj1x/image/upload/v1795369415/Luxury_Ganesha_Rose-Gold_Watch.png',
        'Rose Gold', 'Rose Gold', 'Leather', 'Automatic', '50 m (5 ATM)', true, 11, 36, 825000, 3,
        'Lord Ganesha, remover of obstacles, crafted on a rose-gold dial to bless every new beginning.' },

    new List<Object>{ 106, 'Rakta Kamal Heritage',
        'https://res.cloudinary.com/pk7hvj1x/image/upload/v1795369790/Front-Facing_Crimson_Floral_Heritage_Watch.png',
        'Red', 'Yellow Gold', 'Leather', 'Manual', '30 m (3 ATM)', true, 15, 36, 560000, 0,
        'Crimson lotus enamel inspired by Malwa miniature art, a heritage piece for the collector.' }
};


/* ================= helper ================= */

Object fit(Map<String, Schema.SObjectField> fields, String apiName, Object wanted, Integer seed) {

    Schema.SObjectField field = fields.get(apiName.toLowerCase());
    if (field == null || wanted == null) {
        return null;
    }
    Schema.DescribeFieldResult d = field.getDescribe();
    if (!d.isCreateable() && !d.isUpdateable()) {
        return null;
    }
    Schema.DisplayType t = d.getType();
    String asText = String.valueOf(wanted);

    if (t == Schema.DisplayType.PICKLIST || t == Schema.DisplayType.MULTIPICKLIST) {
        List<String> active = new List<String>();
        for (Schema.PicklistEntry e : d.getPicklistValues()) {
            if (e.isActive()) active.add(e.getValue());
        }
        if (active.isEmpty()) return null;
        for (String v : active) {
            if (v.equalsIgnoreCase(asText)) return v;
        }
        for (String v : active) {
            String a = v.toLowerCase();
            String b = asText.toLowerCase();
            if (a.contains(b) || b.contains(a)) return v;
        }
        /* first word match, e.g. "Royal Blue" -> "Blue" */
        for (String word : asText.toLowerCase().split(' ')) {
            for (String v : active) {
                if (word.length() > 2 && v.toLowerCase().contains(word)) return v;
            }
        }
        return active[Math.mod(seed, active.size())];
    }

    if (t == Schema.DisplayType.DOUBLE || t == Schema.DisplayType.INTEGER
        || t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.PERCENT) {
        String digits = asText.replaceAll('^[^0-9]*', '').replaceAll('[^0-9.].*$', '');
        return String.isBlank(digits) ? null : Decimal.valueOf(digits);
    }

    if (t == Schema.DisplayType.BOOLEAN) {
        return wanted;
    }

    if (t == Schema.DisplayType.STRING || t == Schema.DisplayType.TEXTAREA || t == Schema.DisplayType.URL) {
        Integer max = d.getLength();
        return (max > 0 && asText.length() > max) ? asText.left(max) : asText;
    }

    return wanted;
}

void put(SObject record, Map<String, Schema.SObjectField> fields, String apiName, Object wanted, Integer seed) {
    Object value = fit(fields, apiName, wanted, seed);
    if (value != null) {
        record.put(apiName, value);
    }
}


/* ================= load ================= */

Savepoint sp = Database.setSavepoint();
Map<String, Schema.SObjectField> productFields = Schema.SObjectType.Product2.fields.getMap();

List<Collection__c> found = [
    SELECT Id, Name FROM Collection__c WHERE Name LIKE :COLLECTION_MATCH LIMIT 1
];
if (found.isEmpty()) {
    System.debug('*** No collection matches ' + COLLECTION_MATCH + '. Nothing done.');
    return;
}
Collection__c collection = found[0];

Pricebook2 standardBook = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
if (!standardBook.IsActive) {
    standardBook.IsActive = true;
    update standardBook;
}

Map<String, Product2> existing = new Map<String, Product2>();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE :(CODE_PREFIX + '%')]) {
    existing.put(p.ProductCode, p);
}

List<Product2> products = new List<Product2>();
Map<String, Decimal> priceByCode = new Map<String, Decimal>();
Map<String, Integer> stockByCode = new Map<String, Integer>();

Integer seed = 0;
for (List<Object> row : WATCHES) {

    String code = CODE_PREFIX + String.valueOf(row[0]);

    Product2 p = new Product2();
    if (existing.containsKey(code)) {
        p.Id = existing.get(code).Id;
    }
    p.ProductCode = code;
    p.Name        = (String) row[1];
    p.IsActive    = true;
    p.Description = (String) row[13];
    p.put('Collection__c', collection.Id);

    put(p, productFields, 'Product_Image_URL__c', row[2],  seed);
    put(p, productFields, 'Brand__c',             'UJJAYINI', seed);
    put(p, productFields, 'Model_Number__c',      'HIR-' + String.valueOf(row[0]) + '-26', seed);
    put(p, productFields, 'Dial_Color__c',        row[3],  seed);
    put(p, productFields, 'Case_Material__c',     row[4],  seed);
    put(p, productFields, 'Strap_Material__c',    row[5],  seed);
    put(p, productFields, 'Movement_Type__c',     row[6],  seed);
    put(p, productFields, 'Water_Resistance__c',  row[7],  seed);
    put(p, productFields, 'Limited_Edition__c',   row[8],  seed);
    put(p, productFields, 'Edition_Size__c',      row[9],  seed);
    put(p, productFields, 'Warranty_Period__c',   row[10], seed);

    products.add(p);
    priceByCode.put(code, Decimal.valueOf(String.valueOf(row[11])));
    stockByCode.put(code, Integer.valueOf(String.valueOf(row[12])));
    seed++;
}

upsert products;

/* ---- prices: update existing standard entry or create one ---- */
Set<Id> productIds = new Map<Id, Product2>(products).keySet();

Map<Id, PricebookEntry> entryByProduct = new Map<Id, PricebookEntry>();
for (PricebookEntry e : [
    SELECT Id, Product2Id FROM PricebookEntry
    WHERE Pricebook2Id = :standardBook.Id AND Product2Id IN :productIds
]) {
    entryByProduct.put(e.Product2Id, e);
}

List<PricebookEntry> entries = new List<PricebookEntry>();
for (Product2 p : products) {
    Decimal price = priceByCode.get(p.ProductCode);
    if (entryByProduct.containsKey(p.Id)) {
        entries.add(new PricebookEntry(Id = entryByProduct.get(p.Id).Id, UnitPrice = price, IsActive = true));
    } else {
        entries.add(new PricebookEntry(Pricebook2Id = standardBook.Id, Product2Id = p.Id, UnitPrice = price, IsActive = true));
    }
}
upsert entries;

/* ---- inventory: only for watches that have none yet ---- */
Set<Id> hasInventory = new Set<Id>();
for (Inventory__c inv : [SELECT Product__c FROM Inventory__c WHERE Product__c IN :productIds]) {
    hasInventory.add(inv.Product__c);
}

List<Inventory__c> inventories = new List<Inventory__c>();
for (Product2 p : products) {
    if (hasInventory.contains(p.Id)) continue;
    Inventory__c inv = new Inventory__c();
    inv.put('Product__c', p.Id);
    inv.put('On_Hand__c', stockByCode.get(p.ProductCode));
    inv.put('Reserved__c', 0);
    inv.put('Inventory_Status__c', 'Active');
    inventories.add(inv);
}
insert inventories;

for (Product2 p : products) {
    System.debug('*** ' + p.ProductCode + ' | ' + p.Name
        + ' | dial ' + p.get('Dial_Color__c')
        + ' | case ' + p.get('Case_Material__c')
        + ' | INR ' + priceByCode.get(p.ProductCode)
        + ' | stock ' + stockByCode.get(p.ProductCode));
}
System.debug('*** ' + collection.Name + ': ' + products.size() + ' watches saved, '
    + inventories.size() + ' new inventory rows.');

if (DRY_RUN) {
    Database.rollback(sp);
    System.debug('*** DRY RUN: rolled back. Set DRY_RUN = false to save.');
}
