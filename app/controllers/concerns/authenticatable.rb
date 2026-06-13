module Authenticatable
  extend ActiveSupport::Concern

  private

  attr_reader :current_subject

  def preference_owner_key
    current_subject.presence || "development"
  end

  def authenticate_request!
    authenticate_web_request!
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

  def allowed_email?(email)
    raw = ENV.fetch("ALLOWED_EMAILS", "")
    return true if raw.blank?

    allowed = raw.split(",").map(&:strip).reject(&:blank?)
    allowed.include?(email)
  end
end
