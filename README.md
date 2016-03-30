diaspora_api
============

Ruby gem to work with Diaspora*

Note: this is not wrapping an official API, since there is no such thing. The gem just makes HTTPS requests and parses answers, which are friendly for parsing due to usage of JSON. The gem will move on the official API as soon it is available. The official API support is in progress.

Usage
-----

### Unofficial API

For the moment, the following actions are available with this gem:
* Log into Diaspora*
* Acquire aspect list
* Post a message
* *There are some more available now, check the source code (PRs with documentation updates are welcome)*

To post a message you can do the following:

```ruby
require "diaspora_api"

c = DiasporaApi::InternalApi.new("https://example-podhost.org")

puts c.login("username", "passowrd")
puts c.post("script test post", "test") # message and aspect


```

### Official API
#### Authorization (new application)
```ruby
require "diaspora_api"
api = DiasporaApi::ApiV1.new("https://example-podhost.org")
cl = api.client_register("client_name") # This registers a new application on the pod
cl.identifier # => "0621bc7...." Save this
cl.secret # => "8ba0f9b..." Save this
api.login("username", "passowrd")
api.authorize_application # Invokes OpenID Connect authorization for the application
```
#### Authorization (previously registered application)
```ruby
require "diaspora_api"
api = DiasporaApi::ApiV1.new("https://example-podhost.org")
cl = api.client_set("client_identifier", "client_secret") # Values saved on registration
api.login("username", "passowrd")
api.authorize_application # Invokes OpenID Connect authorization for the application
```

#### Query user info
```ruby
ui = api.user_info
ui.profile # => https://example-podhost.org/people/a73c...
```