module ManagerAuthentication
  extend ActiveSupport::Concern

  MANAGER_AUTH_COOKIE = :fitxa_cae_manager_id

  included do
    helper_method :current_manager, :manager_signed_in?
  end

  private

  def authenticate_manager!
    return if manager_signed_in?

    session[:manager_return_to] = request.fullpath if request.get? || request.head?
    clear_manager_auth_cookie

    if request.path == admin_root_path
      redirect_to admin_login_path
    else
      redirect_to admin_login_path, alert: t("admin.sessions.flash.require_login")
    end
  end

  def current_manager
    return @current_manager if defined?(@current_manager)

    manager_id = cookies.signed[MANAGER_AUTH_COOKIE]
    @current_manager = Manager.active.find_by(id: manager_id) if manager_id
    clear_manager_auth_cookie unless @current_manager || manager_id.blank?
    @current_manager
  end

  def manager_signed_in?
    current_manager.present?
  end

  def sign_in_manager(manager, remember: false)
    return_to = session.delete(:manager_return_to)

    reset_session
    write_manager_auth_cookie(manager, remember: remember)
    @current_manager = manager

    redirect_to(return_to.presence || admin_root_path)
  end

  def sign_out_manager
    clear_manager_auth_cookie
    @current_manager = nil
  end

  def manager_session_duration(remember:)
    30.days if ActiveModel::Type::Boolean.new.cast(remember)
  end

  def write_manager_auth_cookie(manager, remember:)
    duration = manager_session_duration(remember: remember)
    cookie_options = {
      value: manager.id,
      httponly: true,
      same_site: :lax
    }
    cookie_options[:expires] = duration.from_now if duration

    cookies.signed[MANAGER_AUTH_COOKIE] = cookie_options
  end

  def clear_manager_auth_cookie
    cookies.delete(MANAGER_AUTH_COOKIE)
  end
end
