# lua-resty-route

**lua-resty-route** is a URL routing library for OpenResty supporting
multiple route matchers, middleware, and HTTP and WebSockets handlers
to mention a few of its features.

## Matchers

`lua-resty-route` supports multiple different matchers on routing. Right now
we support these:

* Prefix (case-sensitive and case-insensitive)
* Equals (case-sensitive and case-insensitive)
* Match (using Lua's `string.match` function)
* Regex (case-sensitive and case-insensitive)
* Simple (case-sensitive and case-insensitive)

Matcher is selected by a prefix in a route's pattern, and they do somewhat
follow the Nginx's `location` block prefixes:

Prefix | Matcher | Case-sensitive
-------|---------|---------------
`[none]` | Prefix | ✓
`*` | Prefix | 
`=` | Equals | ✓
`=*` | Equals | 
`#` | Match | ¹
`~` | Regex | ✓
`~*` | Regex | 
`@` | Simple | ✓
`@*` | Simple | 

¹ Lua `string.match` can be case-sensitive or case-insensitive.

## Routing

There are many different ways to define routes in `lua-resty-template`.
It can be said that it is somewhat a Lua DSL for defining routes.

To define routes, you first need a new instance of route. This instance
can be shared with different requests. You may create the routes in
`init_by_lua*`. Here we define a new route instance:

```lua
local route = require "resty.route".new()
```

Now that we do have this `route` instance, we may continue to a next
section, [HTTP Routing](#http-routing).

**Note:** Routes are tried in the order they are added when dispatched.

### Route Arguments

### HTTP Routing

HTTP routing is a most common thing to do in web related routing. That's
why HTTP routing is the default way to route in `lua-resty-route`. Other
types of routing include e.g. [WebSockets routing](#websockets-routing).

The most common HTTP request methods (sometimes referred to as verbs) are:

Method | Definition
-------|-----------
`GET` | Read
`POST` | Create
`PUT` | Update or Replace
`PATCH` | Update or Modify
`DELETE` | Delete

While these are the most common ones, `lua-resty-route` is not by any means
restricted to these. You may use whatever request methods there is just like
these common ones. But to keep things simple here, we will just use these in
the examples.

#### The General Pattern in Routing

```lua
route(...)
route:method(...)
```

e.g.:

```lua
route("get", "/", function(self) end)
route:get("/", function(self) end)
```

The first example takes one to three arguments, and the second one takes one or
two arguments. Only the first function argument is mandatory. That's why we can
call these functions in a quite flexible ways. Next we look at different ways to
call these functions.

#### Defining Routes as a Table

```lua
route "=/users" {
    get  = function(self) end,
    post = function(self) end
}
local users = {
    get  = function(self) end,
    post = function(self) end
}
route "=/users" (users)
route("=/users", users)
route "=/users"  "controllers.users"
route("=/users", "controllers.users")
```

**Note:** be careful with this as all the callable string keys in that
table will be used as a route handlers (aka this may lead to unwanted
exposure of a code that you don't want to be called on HTTP requests).

#### Defining Multiple Methods at Once

```lua
route { "get", "head" } "=/users" (function(self) end)
route { "get", "head" } "=/users" {
    head = function(self) end,
    get  = function(self) end
}
```

#### Defining Multiple Routes at Once

```lua
route {
    ["/"] = function(self) end,
    ["=/users"] = {
        get  = function(self) end,
        post = function(self) end
    }
}
```

#### Routing all the HTTP Request Methods

```lua
route "/" (function(self) end)
route("/", function(self) end)
```

#### The Catch all Route

```lua
route(function(self) end)
```

### WebSockets Routing

### File System Routing

### Dispatching

## Middleware

Middleware in `lua-resty-route` can be defined on either on per request
or per route basis.

## Status Handlers

## Roadmap

This is a small collection of ideas that may or may not be implemented as
a part of `lua-resty-route`.

1. Add more documentation
2. Rewrite current middleware and add new ones
3. Rewrite current websocket handler
4. Add route statistics
5. Add automatic route cleaning (possibly configurable) (clean function is already written)
6. Add automatic slash-handling and redirecting (possibly configurable)
7. Add a more automated way to define redirects
8. Add a support for easy way to define Web Hooks routes
9. Add a support for easy way to define Server Sent Events routes
10. Add a support for "provides", e.g. renderers
11. Add support for conditions, e.g. content negotiation
12. Add support for named routes or aliases
13. ~~Add `\Q` and `\E` regex quoting to simple matcher~
14. Add tests

## License

`lua-resty-route` uses two clause BSD license.

```
Copyright (c) 2015 – 2017, Aapo Talvensaari
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES`
