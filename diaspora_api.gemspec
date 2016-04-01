Gem::Specification.new do |s|
  s.name        = 'diaspora_api'
  s.version     = '0.0.6.dev'
  s.date        = '2016-03-24'
  s.summary     = "Diaspora* client"
  s.description = "Ruby gem to work with Diaspora*. Note: this is not wrapping an official API, since there is no such thing. The gem just makes HTTPS requests and parses answers, which are friendly for parsing due to usage of JSON."
  s.authors     = ["cmrd Senya"]
  s.email       = 'senya@riseup.net'
  s.files       = Dir["lib/**/*"]
  s.homepage    =
    'http://rubygems.org/gems/diaspora_api'
  s.license       = 'GPL-3.0'

  s.add_dependency "openid_connect"
end

