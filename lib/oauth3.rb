require 'oauth2'
require 'httpclient'
require 'json'

class Oauth3
  #attr_reader :client
  #attr_accessor :options

  OAuth2::Response.register_parser(:text, 'text/plain') do |body|
    if '{' == body[0] or '[' == body[0]
      MultiJson.load(body) rescue body
    else
      Rack::Utils.parse_query(body)
    end
  end

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

    registration = @registrar.get(provider_uri)
    dynamic = true

    if registration and registration['directives']
      directives = registration['directives']
      dynamic = false
    else
      # TODO if there's no prefix (https://), add it first
      # TODO if the directive is stale, refresh it
      http = HTTPClient.new()
      response = http.get_content("#{provider_uri}/oauth3.json")
      directives = JSON.parse(response)
    end

    @providers[provider_uri] = {
      provider_uri: provider_uri,
      directive: directives,
      timestamp: Time.now,
      dynamic: dynamic
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
    token_method = (get_directive(provider_uri)['access_token']['method'] || 'POST').downcase.to_sym
    client_options[:token_method] = token_method

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
    authorization_code_callback_uri = @options[:authorization_code_callback_uri] || @options[:redirect_uri]
    rnd = random_string()

    @states[rnd] = {
      created_at: Time.now,
      provider_uri: provider_uri,
      params: params
    }

    get_oauth2_client(provider_uri).auth_code.authorize_url({
      # Note that no parameters can be passed tothis redirect
      # It is required to be verbatim for Facebook and probably many other providers
      redirect_uri: authorization_code_callback_uri,
      scope: params[:scope],
      state: rnd
    })
  end

  def authorization_code_callback(params)
    # TODO needs error handling function to make this DRY

    server_state = params[:state] or params[:server_state]
    if not server_state
      if params[:error]
        return params
      else
        return { error: "E_NO_STATE", error_description: "provider_did_not_return_state" }
      end
    end

    meta_state = @@oauth3.get_state(server_state)
    if not meta_state
      return { error: "E_INVALID_SERVER_STATE", error_description: "server_state_missing_or_expired" }
    end

    # TODO provider_uri should not be necessary because we have state
    # (but I don't think oauth3.html implements that completely yet)
    # meta_state = { created_at, provider_uri, params }
    browser_params = meta_state[:params].merge({ provider_uri: meta_state[:provider_uri] })
    if not browser_params
      browser_params = { error: "E_SANITY_FAIL", error_description: "sanity fail: server_state missing browser_params" }
      params.delete(:state)
      return params.merge(browser_params)
    end

    browser_state = browser_params[:state] or browser_params[:browser_state]
    if not browser_state
      browser_params[:error] = "E_INVALID_BROWSER_STATE"
      browser_params[:error_description] = "server_state missing or expired"
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
    get_oauth2_client(provider_uri).auth_code.get_token(code, {
      redirect_uri: @options[:authorization_code_callback_uri]
    })
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
