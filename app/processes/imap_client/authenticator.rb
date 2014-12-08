require 'oauth'
require 'oauth2'
require 'xoauth2_authenticator'

class ImapClient::Authenticator
  attr_accessor :user

  def initialize(user)
    self.user = user
  end

  def authenticate(client)
    code = user.imap_provider.code
    method = "authenticate_#{code.downcase}".to_sym
    return self.send(method, client)
  end

  private unless Rails.env.test?

  ###
  # Google authentication mechanisms.
  ###

  # Private: Connect to Gmail using OAUTH 1.0.
  def authenticate_gmail_oauth1(client)
    return authenticate_oauth_1(client)
  end

  # Private: Connect to Gmail using OAUTH 2.0.
  def authenticate_gmail_oauth2(client)
    return authenticate_oauth2(client)
  end

  ###
  # Generic authentication mechanisms.
  ###

  # Private: Connect via username and password.
  def authenticate_plain(client)
    client.login(user.login_username, user.login_password_secure)
  end

  # Private: Connect via OAUTH 1.0
  def authenticate_oauth_1(client)
    conn  = user.connection
    conn_type = conn.imap_provider

    consumer = OAuth::Consumer.new(
      conn.oauth1_consumer_key_secure,
      conn.oauth1_consumer_secret_secure,
      :site               => conn_type.oauth1_site,
      :request_token_path => conn_type.oauth1_request_token_path,
      :authorize_path     => conn_type.oauth1_authize_path,
      :access_token_path  => conn_type.oauth1_access_token_path)

    access_token = OAuth::AccessToken.new(consumer,
                                          user.oauth1_token_secure,
                                          user.oauth1_token_secret_secure)

    client.authenticate('XOAUTH', user.email, :access_token => access_token)
  end

  # Private: Connect via OAUTH 2.0
  def authenticate_oauth2(client)
    conn = user.connection
    conn_type = conn.imap_provider

    oauth_client = OAuth2::Client.new(
      conn.oauth2_client_id_secure,
      conn.oauth2_client_secret_secure,
      {
        :site         => conn_type.oauth2_site,
        :token_url    => conn_type.oauth2_token_url,
        :token_method => conn_type.oauth2_token_method.to_sym,
        :grant_type   => conn_type.oauth2_grant_type,
        :scope        => conn_type.oauth2_scope
      })

    oauth2_access_token = oauth_client.get_token(
      {
        :client_id     => conn.oauth2_client_id_secure,
        :client_secret => conn.oauth2_client_secret_secure,
        :refresh_token => user.oauth2_refresh_token_secure,
        :grant_type    => conn_type.oauth2_grant_type
      })

    client.authenticate('XOAUTH2', user.email, oauth2_access_token.token)
  end
end
