class ApplicationController < ActionController::Base
  include Authenticatable

  protect_from_forgery with: :exception, unless: :api_request?

  before_action :authenticate_request!

  private

  # Api::UserPreferencesController など JSON 応答用
  def render_api_error(status, code:, message:, details: nil)
    body = { error: { code: code, message: message } }
    body[:error][:details] = details if details.present?
    render json: body, status: status
  end
end
