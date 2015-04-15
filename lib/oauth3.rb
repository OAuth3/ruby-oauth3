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

  def authorize_url(provider_uri, params)
    provider_uri = @@oauth3.normalize_provider_uri(provider_uri)
    redirect_uri = @options[:redirect_uri]
    rnd = random_string()

    @states[rnd] = {
      created_at: Time.now,
      provider_uri: provider_uri,
      params: params
    }

    # TODO state should go in params to the provider, not the redirect directly
    # ... but ultimately it has the same effect, so whatever
    get_oauth2_client(provider_uri).auth_code.authorize_url({
      # TODO (change ? to & if there's already a ?)
      redirect_uri: redirect_uri + "?state=" + rnd
    })
  end

  def authorization_code_callback(params)
    # TODO needs error handling function to make this DRY

    if not params[:state]
      if params[:error]
        return params
      else
        return { error: "E_NO_STATE", error_description: "provider_did_not_return_state" }
      end
    end

    original_state = @@oauth3.get_state(params[:state])
    if not original_state
      return { error: "E_INVALID_SERVER_STATE", error_description: "server_state_missing_or_expired" }
    end

    # TODO provider_uri should not be necessary because we have state
    # (but I don't think oauth3.html implements that completely yet)
    # original_state = { created_at, provider_uri, params }
    browser_params = original_state[:params].merge({ provider_uri: original_state[:provider_uri] })
    if not browser_params
      browser_params = { error: "E_SANITY_FAIL", error_description: "sanity_fail_server_state_missing_params" }
      params.delete(:state)
      return params.merge(browser_params)
    end

    browser_state = browser_params[:state] or browser_params[:browser_state]
    if not browser_state
      browser_params[:error] = "E_INVALID_BROWSER_STATE"
      browser_params[:error_description] = "state_missing_or_expired"
      return browser_params
    end

    # TODO decide on one or the other. Favor explicit to avoid confusion?
    result_params = { browser_state: browser_state, state: browser_state }
    if params[:error]
      params.delete(:state)
      return params.merge(result_params)
    end

    code = params[:code]

    if not code
      result_params[:error] = "E_INVALID_BROWSER_STATE"
      result_params[:error_description] = "state_missing_or_expired"
      params.delete(:state)
      return params.merge(result_params)
    end

    provider_uri = browser_params[:provider_uri]
    if token = @@oauth3.get_token(provider_uri, code).token
      result_params[:access_token] = token
    end

    # Note in the future the server will send back
    #   granted_scopes=foo,bar,baz,etc
    #   expires_at=2015-04-01T12:30:00.000Z
    #   app_scoped_id=<<default-account-app-scoped-id>>
    params.delete(:state)
    params.merge(result_params)
  end

  def get_state(state)
    @states.delete(state)
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
