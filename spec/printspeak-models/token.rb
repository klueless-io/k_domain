class Token < ActiveRecord::Base
  belongs_to :user, required: true
  validates :user, presence: { message: "must exist" }

  attr_encrypted :access_token, key: Base64.decode64(Rails.application.secrets.credentials_secret_key || ENV["CREDENTIALS_SECRET_KEY"])
  attr_encrypted :refresh_token, key: Base64.decode64(Rails.application.secrets.credentials_secret_key || ENV["CREDENTIALS_SECRET_KEY"])

  def self.authenticate(*args)
    ActionController.HttpAuthentication::Token.authenticate(*args)
  end

  def to_params
    {"refresh_token" => refresh_token,
     "client_id" => Rails.application.secrets.google_client_id,
     "client_secret" => Rails.application.secrets.google_client_secret,
     "grant_type" => "refresh_token"}
  end

  def request_token_from_google
    url = URI("https://accounts.google.com/o/oauth2/token")
    result = nil
    begin
      result = Net::HTTP.post_form(url, to_params)
    rescue StandardError
      # TODO this will hide the SSL error, but it is something we should still fix
    end
    result
  end

  def refresh!
    response = request_token_from_google
    token_user = User.unscoped.where(id: user_id).first
    case response
    when Net::HTTPOK
      data = JSON.parse(response.body)
      if !data["access_token"].nil?
        token_user.update_attributes(last_token_refresh_time: Time.now, email_notifications: "") if token_user
        update_attributes(access_token: data["access_token"], expires_at: Time.now + (data["expires_in"].to_i / 2).seconds)
      end
    when Net::HTTPClientError
      data = JSON.parse(response.body)
      token_user.update_attributes(email_notifications: "Email no longer authorized") if token_user
      destroy if data["error"] == "invalid_grant"
    end
  end

  def expired?
    expires_at < Time.now || access_token.blank?
  end

  def fresh_token
    refresh! if expired?
    access_token
  end

  def authorization
    require "signet/oauth_2/client"
    Signet::OAuth2::Client.new(
      authorization_uri: "https://accounts.google.com/o/oauth2/auth",
      token_credential_uri: "https://www.googleapis.com/oauth2/v3/token",
      client_id: Rails.application.secrets.google_client_id,
      client_secret: Rails.application.secrets.google_client_secret,
      access_token: fresh_token,
      expires_at: expires_at
    )
  end
end
