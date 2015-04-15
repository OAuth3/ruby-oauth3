Gem::Specification.new do |s|
  s.name        = "oauth3"
  s.version     = "1.0.4"
  s.date        = "2015-04-14"
  s.summary     = "OAuth3 (backwards compatible with OAuth2) authentication strategy for connecting to any OAuth2 / OAuth3 provider in Ruby / Sinatra / etc"
  s.authors     = ["AJ ONeal"]
  s.email       = "coolaj86@gmail.com"
  s.files       = ["lib/oauth3.rb"]
  s.homepage    = "https://github.com/OAuth3/ruby-oauth3-gem"
  s.license     = "TRON"

  s.add_dependency "oauth2",        "1.0.0"
  s.add_dependency "httpclient",    "2.6.0"
  s.add_dependency "json",          "1.8.2"
end
