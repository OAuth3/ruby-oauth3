require 'oauth2'
require 'httpclient'
require 'json'

class Oauth3
  #attr_reader :client
  #attr_accessor :options

  def initialize(registrar, options={})
    # make sure all options for the OAuth module and faraday
    # pass all the way down
    @options = options
    @states = {}
    @providers = {}
    @clients = {}
    @registrar = registrar
  end

  def normalize_provider_uri(uri)
    'https://' + uri.gsub(/https?:\/\//, '')
  end

  def get_directive(provider_uri)
    if @providers[provider_uri] # and @directive.timestamp < 1.day.old
      return @providers[provider_uri][:directive]
    end

    # TODO if there's no prefix (https://), add it first
    # TODO if the directive is stale, refresh it
    http = HTTPClient.new()
    response = http.get_content("#{provider_uri}/oauth3.json")
    @providers[provider_uri] = {
      provider_uri: provider_uri,
      directive: JSON.parse(response),
      timestamp: Time.now
    }
    @providers[provider_uri][:directive]
  end

  def get_oauth2_client(provider_uri)
    # TODO refresh the client when refreshing the directive
    if @clients[provider_uri]
      return @clients[provider_uri]
    end

    client_options = @options.dup
    client_options[:site] = ""
    client_options[:authorize_url] = get_directive(provider_uri)['authorization_dialog']['url']
    client_options[:token_url] = get_directive(provider_uri)['access_token']['url']

    @clients[provider_uri] = OAuth2::Client.new(
      @registrar.get(provider_uri)['id'],
      @registrar.get(provider_uri)['secret'],
      client_options
    )
  end


  def random_string
    (0...50).map { ('a'..'z').to_a[rand(26)] }.join
  end

  def authorize_url(provider_uri)
    redirect_uri = @options[:redirect_uri]
    rnd = random_string()
    @states[rnd] = Time.now

    # TODO state should go in params to the provider, not the redirect directly
    # ... but ultimately it has the same effect, so whatever
    get_oauth2_client(provider_uri).auth_code.authorize_url(
      # TODO (change ? to & if there's already a ?)
      redirect_uri: redirect_uri +
        "?provider_uri=" + URI.encode_www_form_component(provider_uri) +
        "&state=" + rnd
    )
  end

  def validate_state(provider_uri, state)
    # TODO delete stale states
    @states[state]
  end

  def get_token(provider_uri, code)
    get_oauth2_client(provider_uri).auth_code.get_token(code)
  end

  def get_profile(provider_uri, token)
    url = get_directive(provider_uri)['profile']['url']
    OAuth2::AccessToken.new(get_oauth2_client(provider_uri), token).get(url)
  end

  def get_resource(provider_uri, token, path)
    url = get_directive(provider_uri)['api_base_url']
    OAuth2::AccessToken.new(get_oauth2_client(provider_uri), token).get("#{url}/#{path}")
  end

end
