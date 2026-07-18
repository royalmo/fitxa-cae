module EmployeeAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_employee, :employee_signed_in?
  end

  private

  def authenticate_employee!
    return if employee_signed_in?

    session[:employee_return_to] = request.fullpath if request.get? || request.head?

    if request.path == root_path # I don't want the alert on the landing /
      redirect_to login_path
    else
      redirect_to login_path, alert: t("employee.sessions.flash.require_login")
    end
  end

  def current_employee
    @current_employee ||= Employee.find_by(id: session[:employee_id], active: true) if session[:employee_id]
  end

  def employee_signed_in?
    current_employee.present?
  end

  def sign_in_employee(employee, remember:, installed_pwa:)
    return_to = session.delete(:employee_return_to)

    reset_session
    request.session_options[:expire_after] = employee_session_duration(remember: remember, installed_pwa: installed_pwa)
    session[:employee_id] = employee.id

    redirect_to(return_to.presence || root_path)
  end

  def sign_out_employee
    session.delete(:employee_id)
    request.session_options[:expire_after] = nil
  end

  def store_pending_employee_login(employee, national_id:, delivery_method:, remember:, installed_pwa:)
    session[:pending_employee_login] = {
      "employee_id" => employee&.id,
      "national_id" => Employee.normalize_national_id(national_id),
      "delivery_method" => delivery_method,
      "remember" => remember,
      "installed_pwa" => installed_pwa
    }
  end

  def pending_employee_login
    Employee.find_by(id: pending_employee_login_state["employee_id"], active: true) if pending_employee_login_state["employee_id"]
  end

  def clear_pending_employee_login
    session.delete(:pending_employee_login)
  end

  def pending_employee_login_delivery_method
    pending_employee_login_state["delivery_method"].presence || "email"
  end

  def pending_employee_login_remember?
    ActiveModel::Type::Boolean.new.cast(pending_employee_login_state["remember"])
  end

  def pending_employee_login_installed_pwa?
    ActiveModel::Type::Boolean.new.cast(pending_employee_login_state["installed_pwa"])
  end

  def employee_session_duration(remember:, installed_pwa:)
    return nil unless ActiveModel::Type::Boolean.new.cast(remember)

    ActiveModel::Type::Boolean.new.cast(installed_pwa) ? 1.year : 30.days
  end

  def pending_employee_login_state
    session[:pending_employee_login] || {}
  end

  def pending_employee_login_requested?
    pending_employee_login_state.present?
  end
end
