class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_owner!

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def require_owner!
    redirect_to login_path, alert: "Faça login para continuar." unless logged_in?
  end
end
