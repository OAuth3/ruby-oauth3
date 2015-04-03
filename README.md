# ruby-oauth3-gem

OAuth3 authentication strategy for connecting to any OAuth2 / OAuth3 provider in Ruby / Sinatra / etc

* Authorization Code Strategy (browser / server)
* backwards compatible with OAuth2
* doesn't require knowledge of implementation details
* automatic registration (not yet implemented)

```bash
gem install oauth3
```

```ruby
require "oauth3"
```

```ruby
# see appendix below for example Registrar
registrar = Registrar.new('db.json')
oauth3 = Oauth3.new(registrar, {})
```

## What about my client_id and client_secret?

In the future your app will automatically register itself.

For right now, you'd manually list them in `db.json`.

## Usage

```ruby
provider_uri = "https://example.com"

# changes example.com and http://example.com to https://example.com
provider_uri = oauth3.normalize_provider_uri(provider_uri)

# fetches or returns from cache https://example.com/oauth3.json
oauth3.get_directive(provider_uri)

# constructs authorize_url
oauth3.authorize_url(provider_uri)

# exchanges code for token
oauth3.get_token(provider_uri, code).token

# fetches profile with token
oauth3.get_profile(provider_uri, token)
```

## Example

See <https://github.com/LDSorg/backend-oauth2-ruby-sinatra-example/blob/master/app.rb>

## License

This material and related specifications, copyrights, trademarks, and patents are available under the TRON License.

See https://github.com/OAuth3/TRON-LICENSE

In essense, to use this copyrighted, trademarked, and or patented material you must agree to fight for the users.

## Appendix

Example Registrar
----------------

```json
{ "https://example.com": {
    "id": "some-id"
  , "secret": "some-secret"
  }
}
```

```ruby
class Registrar
  def initialize(filename)
    @filename = filename

    File.open(filename, "r") do |f|
      @store = JSON.parse(f.read())
    end
  end

  # called before attempting to register
  def options
    return {
      allowed_ips: [],
      allowed_domains: [ "example.com", "example.io" ]
    }
  end

  # called when an automatic registration occurs
  def register(provider_uri, id, secret)
    @store[provider_uri] = { 'id' => id, 'secret' => secret }
    File.open(@filename, "w") do |f|
      f.write(JSON.pretty_generate(@store))
    end
  end

  # called when making request to an oauth2 provider
  def get(provider_uri)
    @store[provider_uri]
  end
end
```
