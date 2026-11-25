User u = [SELECT Id FROM User WHERE Username = 'safari@gmail.com' LIMIT 1];
Database.SaveResult r = EventBus.publish(
    new UJJAYINI_Access_Request__e(User_Id__c = String.valueOf(u.Id))
);
System.debug('UJJAYINI publish success: ' + r.isSuccess());