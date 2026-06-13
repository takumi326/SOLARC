class SessionsController < ApplicationController
  layout "sessions"

  def new
    redirect_to root_path if web_signed_in?
  end

  def create
    auth = request.env["omniauth.auth"]
    email = auth&.info&.email.to_s
    if email.blank?
      redirect_to login_path, alert: "Google ログインに失敗しました。"
      return
    end

    unless allowed_email?(email)
      redirect_to login_path, alert: "このメールアドレスは許可されていません。"
      return
    end

    session[:user_email] = email
    redirect_to root_path, notice: "ログインしました。"
  end

  def failure
    message = params[:message].presence || "Google ログインに失敗しました。"
    redirect_to login_path, alert: message
  end

  def destroy
    session.delete(:user_email)
    redirect_to login_path, notice: "サインアウトしました。"
  end

  private

  def web_signed_in?
    return true if Rails.env.development? || Rails.env.test?

    session[:user_email].present? && allowed_email?(session[:user_email])
  end

  def allowed_email?(email)
    raw = ENV.fetch("ALLOWED_EMAILS", "")
    return true if raw.blank?

    raw.split(",").map(&:strip).include?(email)
  end
end
