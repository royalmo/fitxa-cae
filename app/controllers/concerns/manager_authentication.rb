module ManagerAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_manager, :manager_signed_in?
  end

  private

  def authenticate_manager!
    return if manager_signed_in?

    session[:manager_return_to] = request.fullpath if request.get? || request.head?
    session.delete(:manager_id)

    if request.path == admin_root_path
      redirect_to admin_login_path
    else
      redirect_to admin_login_path, alert: t("admin.sessions.flash.require_login")
    end
  end

  def current_manager
    return @current_manager if defined?(@current_manager)

    @current_manager = Manager.active.find_by(id: session[:manager_id]) if session[:manager_id]
  end

  def manager_signed_in?
    current_manager.present?
  end

  def sign_in_manager(manager, remember: false)
    return_to = session.delete(:manager_return_to)

    reset_session
    request.session_options[:expire_after] = manager_session_duration(remember: remember)
    session[:manager_id] = manager.id

    redirect_to(return_to.presence || admin_root_path)
  end

  def sign_out_manager
    session.delete(:manager_id)
    request.session_options[:expire_after] = nil
    @current_manager = nil
  end

  def manager_session_duration(remember:)
    30.days if ActiveModel::Type::Boolean.new.cast(remember)
  end
end
