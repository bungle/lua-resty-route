# lua-resty-route

**lua-resty-route** is a URL routing library for OpenResty supporting
pluggable route matchers.

## Matchers

`lua-resty-route` supports multiple different matchers on routing. Right now
we support these:

* Prefix (case-sensitive and case-insensitive)
* Equals (case-sensitive and case-insensitive)
* Match (using Lua's `string.match` function)
* Regex (case-sensitive and case-insensitive)
* Simple (case-sensitive and case-insensitive)

Matcher is selected by a prefix in a route's pattern, and they do somewhat
follow Nginx `location` prefixes:

Prefix | Matcher | Case-sensitive
-------|---------|---------------
\/ | Prefix | ✓
\*/ | Prefix | 
\=/ | Equals | ✓
\=*/ | Equals | 
\#/ | Match | ¹
\~/ | Regex | ✓
\~*/ | Regex | 
\@/ | Simple | ✓
\@*/ | Simple | 

¹ Lua `string.match` can be case-sensitive or case-insensitive.

## Routing



### HTTP Routing

### WebSockets Routing


## Status Handlers

## Middleware

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
