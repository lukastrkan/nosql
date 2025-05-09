#!js name=lib api_version=1.0

redis.registerFunction('hello_world', function() {
    return 'hello_world';
});
