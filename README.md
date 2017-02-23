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

Prefix   | Matcher | Case-sensitive | Used by Default
---------|---------|----------------|----------------
`[none]` | Prefix  | ✓              | ✓
`*`      | Prefix  |                |
`=`      | Equals  | ✓              |
`=*`     | Equals  |                |
`#`      | Match   | ¹              |
`~`      | Regex   | ✓              |
`~*`     | Regex   |                |
`@`      | Simple  | ✓              |
`@*`     | Simple  |                |

¹ Lua `string.match` can be case-sensitive or case-insensitive.

### Prefix Matcher

Prefix, as the name tells, matches only the prefix of the actual location.
Prefix matcher takes only static string prefixes. If you need anything more
fancy, take a look at regex matcher. Prefix can be matched case-insensitively
by prefixing the prefix with `*`, :-). Let's see this in action:

```lua
route "/users" (function(self) end)
```

This route matches locations like:

* `/users`
* `/users/edit`
* `/users_be_aware`

But it **doesn't** match location paths like:

* `/Users`
* `/USERS/EDIT`

But those can be still be matched in case-insensitive way:

```lua
route "*/users" (function(self) end)
```

### Equals Matcher

This works the same as the prefix matcher, but with this
we match the exact location, to use this matcher, prefix
the route with `=`:

```lua
route "=/users" {
    get = function(self) end
}
```

This route matches only this location:

* `/users` 


Case-insensitive variant can be used also:

```lua
route "=*/users" {
    get = function(self) end
}
```

And this of course matches locations like:

* `/users`
* `/USERS`
* `/usErs`

### Match Matcher

This matcher matches patters using Lua's `string.match` function. Nice
thing about this matcher is that it accepts patterns and also provides
captures. Check Lua's documentation about possible ways to define
[patterns](https://www.lua.org/manual/5.1/manual.html#5.4.1). Here are
some examples:

```lua
route "#/files/(%w+)[.](%w+)" {
    get = function(self, file, ext) end
}
```

This will match location paths like:

* `/files/test.txt` etc.

In that case the provided function (that answers only HTTP `GET`
requests in this example), will be called also with these captures:
`"test"` (function argument `file`) and `txt` (function argument `ext`).

For many, the regular expressions are more familiar and more powerfull. 
That is what we will look next.

### Regex Matcher

Regex or regular expressions is a common way to do pattern matching.
OpenResty has support for PCRE compatible regualar expressions, and
this matcher in particular, uses `ngx.re.match` function:

```lua
route "~^/files/(\\w+)[.](\\w+)$" {
    get = function(self, file, ext) end
}
```

As with the Match matcher example above, the end results are the same
and the function will be called with the captures.

For Regex matcher we also have case-insensitive version:

```lua
route "~*^/files/(\\w+)[.](\\w+)$" {
    get = function(self, file, ext) end
}
```

### Simple Matcher

This matcher is a specialized and limited version of a Regex matcher
with one advantage. It handles type conversions automatically, right
now it only supports integer conversion to Lua number. For example:

```lua
route:get "@/users/:number" (function(self, id) end)
```

You could have location path like:

* `/users/45`

The function above will get `45` as a Lua `number`.

Supported simple capturers are:

* `:string`, that is equal to this regex `[^/]+` (one or more chars, not including `/`)
* `:number`, that is equal to this regex `\d+` (one or more digits that can be turned to Lua number using `tonumber` function)

In future, we may add other capture shortcuts.

Of course there is a case-insensitive version for this matcher as well:

```lua
route:get "@*/users/:number" (function(self, id) end)
```

The simple matcher always matches the location from the beginning to end (partial
matches are not considered).

## Routing

There are many different ways to define routes in `lua-resty-route`.
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
This differs from how Nginx itself handles the `location` blocks.

### HTTP Routing

HTTP routing is the most common thing to do in web related routing. That's
why HTTP routing is the default way to route in `lua-resty-route`. Other
types of routing include e.g. [WebSockets routing](#websockets-routing).

The most common HTTP request methods (sometimes referred to as verbs) are:

Method   | Definition
---------|-----------
`GET`    | Read
`POST`   | Create
`PUT`    | Update or Replace
`PATCH`  | Update or Modify
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

or

```lua
route(method, pattern, func)
route:method(pattern, func)
```

e.g.:

```lua
route("get", "/", function(self) end)
route:get("/", function(self) end)
```

Only the first function argument is mandatory. That's why we can
call these functions in a quite flexible ways. For some `methods`,
e.g. websocket, we can pass a `table` instead of a `function` as
a route handler. Next we look at different ways to call these
functions.

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
```

#### Using Lua Packages for Routing

```lua
route "=/users"  "controllers.users"
route("=/users", "controllers.users")
```

These are same as:

```lua
route("=/users", require "controllers.users")
```

#### Defining Multiple Methods at Once

```lua
route { "get", "head" } "=/users" (function(self) end)
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

#### Going Crazy with Routing

```lua
route:as "@home" (function(self) end)
route {
    get = {
        ["=/"] = "@home",
        ["=/users"] = function(self) end
    },
    ["=/help"] = function(self) end,
    [{ "post", "put"}] = {
        ["=/me"] = function(self)
        end
    },
    ["=/you"] = {
        [{ "get", "head" }] = function(self) end
    },
    [{ "/files", "/cache" }] = {
        -- requiring controllers.filesystem returns a function
        [{"get", "head" }] = "controllers.filesystem"
    }
}
```

As you may see this is pretty freaky. But it doesn't actually
stop here. I haven't even mentioned things like callable Lua
tables (aka tables with metamethod `__call`) or web sockets
routing. They are supported as well.

### WebSockets Routing

### File System Routing

File system routing is based on a file system tree. This could be
considered as a routing by a convention. File system routing depends
on either [LuaFileSystem](https://github.com/keplerproject/luafilesystem)
module or a preferred and LFS compatible
[ljsyscall](https://github.com/justincormack/ljsyscall).

As an example, let's consider that we do have this kind of file tree:

```
/routing/
 ├─ index.lua 
 ├─ users.lua
 └─ users/
 │  ├─ view@get.lua
 │  ├─ edit@post.lua
 │  └─ #/
 │     └─ index.lua
 └─ page/
    └─ #.lua
```

This file tree will provide you with the following routes:

- `@*/` → `index.lua`
- `@*/users` → `users.lua`
- `@*/users/view` → `users/view@get.lua` (only GET requests are routed here)
- `@*/users/edit` → `users/edit@post.lua` (only POST requests are routed here)
- `@*/users/:number` → `users/#/index.lua`
- `@*/page/:number` → `page/#.lua`

The files could look like this (just an example):

`index.lua`:

```lua
return {
    get  = function(self) end,
    post = function(self) end
}
```

`users.lua`:

```lua
return {
    get    = function(self) end,
    post   = function(self) end,
    delete = function(self) end
}   
```

`users/view@get.lua`:

```lua
return function(self) end
```

`users/edit@post.lua`:

```lua
return function(self) end
```

`users/#/index.lua`:

```lua
return {
    get    = function(self, id) end,
    put    = function(self, id) end,
    post   = function(self, id) end,
    delete = function(self, id) end
}
```

`page/#.lua`:

```lua
return {
    get    = function(self, id) end,
    put    = function(self, id) end,
    post   = function(self, id) end,
    delete = function(self, id) end
}
```

To define routes based on file system tree you will need to call `route:fs`
function:

```lua
-- Here we assume that you do have /routing directory
-- on your file system. You may use whatever path you
-- like, absolute or relative.
route:fs "/routing"
```

Using file system routing you can just add new files to file system tree,
and they will be added automatically as a routes.

### Named Routes

You can define named route handlers, and then reuse them in actual routes.

```lua
route:as "@home" (function(self) end)
```

(the use of `@` as a prefix for a named route is optional)

And here we actually attach it to a route:

```lua
route:get "/" "@home"
```

You can also define multiple named routes in a one go:

```lua
route:as {
    home    = function(self) end,
    signin  = function(self) end,
    signout = function(self) end
}
```

or if you want to use prefixes:

```lua
route:as {
    ["@home"]    = function(self) end,
    ["@signin"]  = function(self) end,
    ["@signout"] = function(self) end
}
```

Named routes must be defined before referencing them in routes.
There are or will be other uses to named routers as well. On todo
list there are things like reverse routing and route forwarding to
a named route.

### Dispatching

### Bootstrapping

## Middleware

Middleware in `lua-resty-route` can be defined on either on per request
or per route basis. Middleware are filters that you can add to the request
processing pipeline. As `lua-resty-route` tries to be as unopionated as
possible we don't really restrict what the filters do or how they have to
be written. Middleware can be inserted just flexible as routes, and they
actually do share much of the logic. With one impotant difference. You can
have multiple middleware on the pipeline whereas only one matchin route
will be executed. The middleware can also be yielded (`coroutine.yield`),
and that allows code to be run before and after the router (you can yield
a router as well, but that will never be resumed). If you don't yield,
then the middleware is considered as a before filter.

The most common type of Middleware is request level middleware:

```lua
route:use(function(self)
    -- This code will be run before router:
    -- ...
    self:yield() -- or coroutine.yield()
    -- This code will be run after the router:
    -- ...
end)
```

Now, as you were already hinted, you may add filters to specific routes as well:

```lua
route.filter "=/" (function(self)
    -- this middleware will only be called on a specific route
end)
```

You can use the same rules as with routing there, e.g.

```lua
route.filter:post "middleware.csrf"
```

Of course you can also do things like:

```lua
route.filter:delete "@/users/:number" (function(self, id)
    -- here we can say prevent deleting the user who
    -- issued the request or something.
end)
```

All the matching middleware is run on every request, unless one of them
decides to `exit`, but we do always try to run after filters for those
middleware that already did run, and yielded. But we will call them in
reverse order:

1. middleware 1 runs and yields
3. middleware 2 runs (and finishes)
4. middleware 3 runs and yields
5. router runs
6. middleware 3 resumes
7. middleware 1 resumes

The order of middleware is by scope:

1. request level middleware is executed first
2. router level middleware is executed second

If there are multiple requet or router level middleware, then they will be
executed the same order they were added to a specific scope. Yielded middleware
is executed in reverse order. Yielded middleware will only be resumed once.

Internally we do use Lua's great `coroutines`.

We are going to support a bunch of predefined middleware in a future.

## Events

Events allow you to register specialized handlers for different HTTP status
codes or other predefined event codes. There can be only one handler for each
code or code group.

You can for example define `404` aka route not found handler like this:

```lua
route:on(404, function(self) end)
```

Some groups are predefined, e.g.:

* `info`, status codes 100 – 199
* `success`, status codes 200 – 299
* `redirect`, status codes 300 – 399
* `client error`, status codes 400 – 499
* `server error`, status codes 500 – 599
* `error`, status codes 400 – 599

You may use groups like this:

```lua
route:on "error" (function(self, code) end)
```

You can also define multiple event handlers in a one go:

```lua
route:on {
    error   = function(self, code) end,
    success = function(self, code) end,
    [302]   = function(self) end
}
```

Then there is a generic catch-all event handler:

```lua
route:on(function(self, code) end)
```

We will find the right event handler in this order:

1. if there is a specific handler for a specific code, we will call that
2. if there is a group handler for specific code, we will call that
3. if there is a catch-all handler, we will call that

Only one of these is called per event.

It is possible that we will add other handlers in a future where you could
hook on.

## Roadmap

This is a small collection of ideas that may or may not be implemented as
a part of `lua-resty-route`.

* Add more documentation
* Add tests
* Rewrite current middleware and add new ones
* Rewrite current websocket handler
* Add route statistics
* Add an automatic route cleaning and redirecting (possibly configurable) (clean function is already written)
* Add an automatic slash handling and redirecting (possibly configurable)
* Add a more automated way to define redirects
* Add a support for easy way to define Web Hooks routes
* Add a support for easy way to define Server Sent Events routes
* Add a support for "provides", e.g. renderers (?)
* Add a support for conditions, e.g. content negotiation
* ~~Add a support for named routes~~
* Add a support for route grouping (already possible on Nginx at config level)
* Add a support for reverse routing
* ~~Add a support for `router:to` to route to a named route~~
* Add a support for form method spoofing
* Add a support for client connection abort event handler (`ngx.on_abort`)
* ~~Add a support for some simple patterns (e.g. `#` for a number) to file system router~~
* ~~Add `\Q` and `\E` regex quoting to simple matcher~~
* Add bootstrapping functionality from Nginx configs
* Add support for Resources (or view sets)
* Add filesystem support for resources (or view sets)


## See Also

* [lua-resty-reqargs](https://github.com/bungle/lua-resty-reqargs) — Request arguments parser
* [lua-resty-session](https://github.com/bungle/lua-resty-session) — Session library
* [lua-resty-template](https://github.com/bungle/lua-resty-template) — Templating engine
* [lua-resty-validation](https://github.com/bungle/lua-resty-validation) — Validation and filtering library

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
