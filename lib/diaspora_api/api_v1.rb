require "openid_connect"

class DiasporaApi::ApiV1 < DiasporaApi::Client
  def current_version
    1
  end

  attr_writer :scopes

  def scopes
    @scopes ||= %w(sub aud profile picture nickname name read write)
  end

  def client_set(client_id, client_secret)
    @client = OpenIDConnect::Client.new(
      identifier: client_id,
      secret: client_secret
    )
    setup_client
    @client
  end

  def client_register(client_name)
    openid_registrar.redirect_uris = ["#{@poduri}/"]
    openid_registrar.client_name=client_name
    @client = openid_registrar.register!
    setup_client
    @client
  end

  def authorize_application
    response = send_request(Net::HTTP::Get.new(authorization_uri, initheader = {"x-csrf-token" => @atok}))
    fetch_csrf(response)
    @logger.debug("body #{response.body}")
    auth_code = fetch_auth_code(approve_application)
    @logger.debug("received auth_code: #{auth_code}")
    if auth_code.nil?
      @logger.error("Failed to receive the authorization code")
      return nil
    end
    @client.authorization_code = auth_code
    @access_token = @client.access_token!
    return nil unless validate_access_token

    access_token
  end

  def public_key
    @public_key ||= fetch_public_key
  end

  def access_token
    @access_token.access_token
  end

  def user_info
    @access_token.userinfo!
  end

  private

  def validate_access_token
    decoded_token = OpenIDConnect::ResponseObject::IdToken.decode(@access_token.id_token, public_key)
    unless decoded_token.nonce == "hi" && decoded_token.exp > Time.now.utc.to_i
      @logger.error("Failed to decode the id token")
      return false
    end

    unless access_token_checksum(@access_token.access_token) == decoded_token.at_hash
      @logger.error("Access token checksum is wrong")
      return false
    end

    true
  end

  def access_token_checksum(access_token)
    UrlSafeBase64.encode64(OpenSSL::Digest::SHA256.digest(access_token)[0, 128 / 8])
  end

  def fetch_public_key
    response = send_plain_request(Net::HTTP::Get.new("/api/openid_connect/jwks.json"))
    return nil unless response.code == "200"

    json = JSON.parse(response.body).with_indifferent_access
    jwks = JSON::JWK::Set.new json[:keys]
    public_keys = jwks.map do |jwk|
      JSON::JWK.new(jwk).to_key
    end
    public_keys.first
  end

  def approve_application
    send_request(Net::HTTP::Post.new("/api/openid_connect/authorizations?approve=true", initheader = {"x-csrf-token" => @atok}))
  end

  def fetch_auth_code(response)
    logger.debug("fetch_auth_code: body = #{response.body}")
    return nil unless response.code == "302"
    /<a href=\"#{@poduri}\/\?code=([^\"]+)\"/.match(response.body)[1]
  end

  def authorization_uri
    @client.authorization_uri(scope: self.scopes, nonce: "hi", state: "hi")
  end

  def setup_client
    @client.authorization_endpoint = openid_config.authorization_endpoint
    @client.userinfo_endpoint = openid_config.userinfo_endpoint
    @client.token_endpoint = openid_config.token_endpoint
    @client.redirect_uri = "#{@poduri}/" if @client.redirect_uri.nil?
  end

  def openid_config_discovery
    WebFinger.url_builder = URI::HTTP if pod_scheme == "http"
    SWD.url_builder = URI::HTTP if pod_scheme == "http"
    res = OpenIDConnect::Discovery::Provider.discover! @poduri
    OpenIDConnect::Discovery::Provider::Config.discover! res.issuer
  end

  def openid_config
    @openid_config ||= openid_config_discovery
  end

  def openid_registrar
    @openid_registrar ||= OpenIDConnect::Client::Registrar.new(openid_config.registration_endpoint)
  end
end
