List<Webhook_Event__c> events = [
    SELECT Id, Event_ID__c
    FROM Webhook_Event__c
    LIMIT 1
];

System.debug('===== WEBHOOK FIELD TEST =====');
System.debug('RECORD COUNT: ' + events.size());

if (!events.isEmpty()) {
    System.debug('EVENT ID: ' + events[0].Event_ID__c);
}