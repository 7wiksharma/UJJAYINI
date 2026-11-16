User u = [
    SELECT Id
    FROM User
    WHERE Id = '005bm00000bbpRGAAY'
    LIMIT 1
];

System.setPassword(u.Id, 'UjjayiniTest@123');
System.debug('PASSWORD RESET SUCCESSFULLY');
