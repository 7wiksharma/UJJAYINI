/*
 * Agentforce custom action: "Find UJJAYINI Watches"
 * ------------------------------------------------
 * Used by the UJJAYINI Concierge (Agentforce Service Agent) on the
 * Experience Cloud site. It answers questions such as
 *   "Show me a blue automatic watch under 3 lakh"
 *   "Something in gold from Hiranya"
 *
 * Only PUBLIC catalogue data is returned (the same data a guest sees on
 * the Watches page): name, collection, key specs, price, availability
 * and a link. No record Ids, product codes, orders or customer data.
 *
 * The agent decides WHEN to call this from the label/descriptions below,
 * so they are written for the agent to read.
 */
public with sharing class UJJAYINIWatchConciergeAction {

    private static final Integer MAX_RESULTS = 5;
    private static final Integer LOW_STOCK = 2;

    // Change this if your Product Detail page has a different URL.
     private static final String DETAIL_PATH = '/ujjayini/product-detail?productId=01tbm00000VJrZrAAL';

    public class Request {

        @InvocableVariable(
            label='Collection'
            description='Optional. The UJJAYINI collection the customer wants: Indranila (blue, sapphire, moon, night), Hiranya (gold, sun, heritage) or Ayas (steel, titanium, engineered).'
        )
        public String collection;

        @InvocableVariable(
            label='Minimum price (INR)'
            description='Optional. Lowest price in Indian rupees. Convert lakh to rupees (1 lakh = 100000).'
        )
        public Decimal minPrice;

        @InvocableVariable(
            label='Maximum price (INR)'
            description='Optional. Highest price in Indian rupees the customer wants to pay. Convert lakh to rupees (1 lakh = 100000).'
        )
        public Decimal maxPrice;

        @InvocableVariable(
            label='Keywords'
            description='Optional. Words describing what the customer wants, separated by spaces, for example: gold diver, blue moonphase, titanium skeleton, rose gold, automatic, leather strap.'
        )
        public String keywords;
    }


    public class Response {

        @InvocableVariable(
            label='Matching watches'
            description='Up to 5 matching watches, one per line, with collection, specs, price in INR, availability and a link to the watch page. Show these to the customer.'
        )
        public String watches;

        @InvocableVariable(
            label='Match count'
            description='How many watches matched in total.'
        )
        public Integer matchCount;
    }


    @InvocableMethod(
        label='Find UJJAYINI Watches'
        description='Searches active UJJAYINI timepieces by collection, price range and keywords (dial colour, case material, movement, strap or style). Use it whenever a customer asks for watch suggestions, prices or availability.'
    )
    public static List<Response> findWatches(List<Request> requests) {

        /*
         * Bulk-safe: the catalogue is read ONCE for all requests,
         * then each request is filtered in memory.
         */
        Map<Id, Decimal> priceByProduct = new Map<Id, Decimal>();
        Id standardBookId = standardPricebookId();

        if (standardBookId != null) {
            for (PricebookEntry entry : [
                SELECT Product2Id, UnitPrice
                FROM PricebookEntry
                WHERE IsActive = true
                AND Pricebook2Id = :standardBookId
                AND Product2.IsActive = true
                WITH SYSTEM_MODE
            ]) {
                priceByProduct.put(entry.Product2Id, entry.UnitPrice);
            }
        }

        Map<Id, Decimal> availableByProduct = new Map<Id, Decimal>();
        for (Inventory__c inventory : [
            SELECT Product__c, Available__c
            FROM Inventory__c
            WHERE Inventory_Status__c = 'Active'
            WITH SYSTEM_MODE
        ]) {
            Decimal current = availableByProduct.get(inventory.Product__c);
            Decimal add = inventory.Available__c == null ? 0 : inventory.Available__c;
            availableByProduct.put(inventory.Product__c, (current == null ? 0 : current) + add);
        }

        List<Product2> catalogue = [
            SELECT Id, Name, Description,
                   Collection__r.Name,
                   Case_Material__c, Dial_Color__c, Movement_Type__c, Strap_Material__c,
                   Limited_Edition__c
            FROM Product2
            WHERE IsActive = true
            AND Product_Image_URL__c != null
            WITH SYSTEM_MODE
            ORDER BY Name
            LIMIT 500
        ];

        List<Response> responses = new List<Response>();

        for (Request request : requests) {

            List<String> lines = new List<String>();
            Integer matches = 0;

            String wantedCollection = norm(request == null ? null : request.collection);
            List<String> words = new List<String>();
            if (request != null && String.isNotBlank(request.keywords)) {
                for (String word : norm(request.keywords).split('\\s+')) {
                    if (word.length() > 1) {
                        words.add(word);
                    }
                }
            }

            for (Product2 product : catalogue) {

                String collectionName = product.Collection__r == null ? '' : product.Collection__r.Name;
                Decimal price = priceByProduct.get(product.Id);

                // Collection
                if (String.isNotBlank(wantedCollection)
                    && !norm(collectionName).contains(wantedCollection.left(4))) {
                    continue;
                }

                // Price range (watches without a price are skipped when a range is asked)
                if (request != null && (request.minPrice != null || request.maxPrice != null)) {
                    if (price == null) { continue; }
                    if (request.minPrice != null && price < request.minPrice) { continue; }
                    if (request.maxPrice != null && price > request.maxPrice) { continue; }
                }

                // Keywords: every word must appear somewhere in the watch's text
                if (!words.isEmpty()) {
                    String haystack = norm(joinText(new List<Object>{
                        product.Name,
                        collectionName,
                        product.Case_Material__c,
                        product.Dial_Color__c,
                        product.Movement_Type__c,
                        product.Strap_Material__c,
                        product.Description,
                        product.Limited_Edition__c == true ? 'limited edition' : null
                    }));

                    Boolean all = true;
                    for (String word : words) {
                        if (!haystack.contains(word)) { all = false; break; }
                    }
                    if (!all) { continue; }
                }

                matches++;

                if (lines.size() < MAX_RESULTS) {
                    lines.add(describe(product, collectionName, price, availableByProduct.get(product.Id)));
                }
            }

            Response response = new Response();
            response.matchCount = matches;
            response.watches = lines.isEmpty()
                ? 'No UJJAYINI watch matches these preferences right now.'
                : String.join(lines, '\n');
            responses.add(response);
        }

        return responses;
    }


    private static String describe(Product2 product, String collectionName, Decimal price, Decimal available) {

        List<String> specs = new List<String>();
        for (Object value : new List<Object>{
            product.Movement_Type__c, product.Case_Material__c, product.Dial_Color__c, product.Strap_Material__c
        }) {
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                specs.add(String.valueOf(value));
            }
        }

        String availability;
        if (available == null || available <= 0) {
            availability = 'currently sold out (a Notify Me request can be placed on its page)';
        } else if (available <= LOW_STOCK) {
            availability = 'only a few pieces left';
        } else {
            availability = 'available';
        }

        return '• ' + product.Name
            + (String.isBlank(collectionName) ? '' : ' (' + collectionName + ')')
            + (specs.isEmpty() ? '' : ' — ' + String.join(specs, ', '))
            + (product.Limited_Edition__c == true ? ' — limited edition' : '')
            + ' — ' + (price == null ? 'price on request' : 'INR ' + price.setScale(0).format())
            + ' — ' + availability
            + ' — ' + DETAIL_PATH + product.Id;
    }


    /*
     * The Standard Price Book cannot be queried inside Apex tests,
     * so tests use Test.getStandardPricebookId() instead.
     */
    private static Id standardPricebookId() {

        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }

        List<Pricebook2> books = [
            SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1
        ];

        return books.isEmpty() ? null : books[0].Id;
    }


    // Joins only the non-empty values (null never becomes the text "null").
    private static String joinText(List<Object> values) {
        List<String> parts = new List<String>();
        for (Object value : values) {
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                parts.add(String.valueOf(value));
            }
        }
        return String.join(parts, ' ');
    }


    // Lower case, accents removed (Indranīla -> indranila), trimmed.
    private static String norm(String value) {
        if (value == null) {
            return '';
        }
        return value.toLowerCase()
            .replace('ī', 'i').replace('ā', 'a').replace('ū', 'u')
            .trim();
    }
}