module ManagerAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_manager, :manager_signed_in?
  end

  private

  def authenticate_manager!
    return if manager_signed_in?

    session[:manager_return_to] = request.fullpath if request.get?
    session.delete(:manager_id)

    redirect_to admin_login_path, alert: t("admin.sessions.flash.require_login")
  end

  def current_manager
    return @current_manager if defined?(@current_manager)

    @current_manager = Manager.active.find_by(id: session[:manager_id]) if session[:manager_id]
  end

  def manager_signed_in?
    current_manager.present?
  end

  def sign_in_manager(manager)
    return_to = session.delete(:manager_return_to)

    reset_session
    session[:manager_id] = manager.id

    redirect_to(return_to.presence || admin_root_path, notice: t("admin.sessions.flash.signed_in"))
  end

  def sign_out_manager
    session.delete(:manager_id)
    @current_manager = nil
  end
end
