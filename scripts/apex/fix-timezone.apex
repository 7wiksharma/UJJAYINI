List<User> users = [
    SELECT Id, Name
    FROM User
    WHERE IsActive = true
    AND (ContactId != null OR UserType = 'Guest')
    AND TimeZoneSidKey != 'Asia/Kolkata'
];

for (User u : users) {
    u.TimeZoneSidKey = 'Asia/Kolkata';
}

update users;
System.debug('Updated users: ' + users.size());