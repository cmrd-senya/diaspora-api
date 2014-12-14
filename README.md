diaspora-api
============

Ruby gem to work with Diaspora*

Note: this is not wrapping an official API, since there is no such thing. The gem just makes HTTPS requests and parses answers, which are friendly for parsing due to usage of JSON.

Usage
-----

For the moment, the following actions are available with this gem:
* Log into Diaspora*
* Acquire aspect list
* Post a message

To post a message you can do the following:

```
require "diaspora-api"

c = DiasporaApi::Client.new

puts c.login("https://example-podhost.org", "username", "passowrd")
puts c.post("script test post", "test")


```

