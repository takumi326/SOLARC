require "json"
require "net/http"
require "uri"

module Authenticatable
  extend ActiveSupport::Concern

  private

  attr_reader :current_subject

  def preference_owner_key
    current_subject.presence || "development"
  end

  def api_request?
    self.class.name.start_with?("Api::") || request.path.start_with?("/api/")
  end

  def authenticate_request!
    if api_request?
      authenticate_api_request!
    else
      authenticate_web_request!
    end
  end

  def authenticate_api_request!
    return if Rails.env.test? || Rails.env.development?

    token = bearer_token
    if token.blank?
      render json: {
        error: {
          code: "missing_token",
          message: "Authorization に Bearer トークンがありません。"
        }
      }, status: :unauthorized
      return
    end

    payload = decode_supabase_jwt(token)
    email = payload["email"].to_s
    if payload.blank? || email.blank?
      render json: {
        error: {
          code: "invalid_token",
          message: "JWT の検証に失敗しました。Render の SUPABASE_URL をフロントの Supabase プロジェクト URL と一致させてください。"
        }
      }, status: :unauthorized
      return
    end

    unless allowed_email?(email)
      render json: {
        error: {
          code: "email_not_allowed",
          message: "このメールアドレスは許可されていません（環境変数 ALLOWED_EMAILS を確認してください）。"
        }
      }, status: :forbidden
      return
    end

    @current_subject = email
  end

  def authenticate_web_request!
    return if Rails.env.test? || Rails.env.development?
    return if sessions_controller?

    if session[:user_email].blank?
      redirect_to login_path
      return
    end

    unless allowed_email?(session[:user_email])
      session.delete(:user_email)
      redirect_to login_path, alert: "このメールアドレスは許可されていません。"
      return
    end

    @current_subject = session[:user_email]
  end

  def sessions_controller?
    is_a?(SessionsController)
  end

  def bearer_token
    auth_header = request.headers["Authorization"].to_s
    return nil unless auth_header.start_with?("Bearer ")

    auth_header.delete_prefix("Bearer ").strip
  end

  def decode_supabase_jwt(token)
    return {} if token.blank?
    return {} if supabase_url.blank?

    decoded, = JWT.decode(token, nil, true, {
      algorithms: %w[RS256 ES256],
      jwks: ->(_options) { supabase_jwks },
      verify_iss: true,
      iss: "#{supabase_url}/auth/v1"
    })
    decoded.is_a?(Hash) ? decoded : {}
  rescue JWT::DecodeError, JWT::JWKError, JSON::ParserError, OpenSSL::SSL::SSLError, SocketError
    {}
  end

  def allowed_email?(email)
    raw = ENV.fetch("ALLOWED_EMAILS", "")
    return true if raw.blank?

    allowed = raw.split(",").map(&:strip).reject(&:blank?)
    allowed.include?(email)
  end

  def supabase_url
    ENV.fetch("SUPABASE_URL", "").delete_suffix("/")
  end

  def supabase_jwks
    cached = self.class.instance_variable_get(:@supabase_jwks_cache)
    now = Time.now.to_i
    return cached[:set] if cached && cached[:expires_at] > now

    jwks_url = ENV.fetch("SUPABASE_JWKS_URL", "#{supabase_url}/auth/v1/.well-known/jwks.json")
    response = Net::HTTP.get_response(URI.parse(jwks_url))
    return JWT::JWK::Set.new({ keys: [] }) unless response.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(response.body)
    set = JWT::JWK::Set.new(parsed)
    self.class.instance_variable_set(:@supabase_jwks_cache, { set: set, expires_at: now + 300 })
    set
  rescue StandardError
    JWT::JWK::Set.new({ keys: [] })
  end
end
