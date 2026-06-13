class ApplicationController < ActionController::Base
  include Authenticatable

  protect_from_forgery with: :exception

  before_action :authenticate_request!
end
