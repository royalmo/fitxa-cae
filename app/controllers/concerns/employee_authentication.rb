module EmployeeAuthentication
  extend ActiveSupport::Concern

  EMPLOYEE_AUTH_COOKIE = :fitxa_cae_employee_id

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
    return @current_employee if defined?(@current_employee)

    employee_id = cookies.signed[EMPLOYEE_AUTH_COOKIE]
    @current_employee = Employee.find_by(id: employee_id, active: true) if employee_id
    clear_employee_auth_cookie unless @current_employee || employee_id.blank?
    @current_employee
  end

  def employee_signed_in?
    current_employee.present?
  end

  def sign_in_employee(employee, remember:, installed_pwa:)
    return_to = session.delete(:employee_return_to)

    reset_session
    write_employee_auth_cookie(employee, remember: remember, installed_pwa: installed_pwa)
    @current_employee = employee

    redirect_to(return_to.presence || root_path)
  end

  def sign_out_employee
    clear_employee_auth_cookie
    @current_employee = nil
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

  def write_employee_auth_cookie(employee, remember:, installed_pwa:)
    duration = employee_session_duration(remember: remember, installed_pwa: installed_pwa)
    cookie_options = {
      value: employee.id,
      httponly: true,
      same_site: :lax
    }
    cookie_options[:expires] = duration.from_now if duration

    cookies.signed[EMPLOYEE_AUTH_COOKIE] = cookie_options
  end

  def clear_employee_auth_cookie
    cookies.delete(EMPLOYEE_AUTH_COOKIE)
  end

  def pending_employee_login_state
    session[:pending_employee_login] || {}
  end

  def pending_employee_login_requested?
    pending_employee_login_state.present?
  end
end
