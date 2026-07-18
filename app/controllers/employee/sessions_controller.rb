class Employee::SessionsController < ApplicationController
  CODE_REQUEST_RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  layout "employee_auth"

  rate_limit to: 10,
    within: 5.minutes,
    only: :request_code,
    store: CODE_REQUEST_RATE_LIMIT_STORE,
    with: :redirect_to_code_request_rate_limit

  before_action :redirect_signed_in_employee, only: %i[new]
  before_action :load_pending_employee_login, only: %i[code verify_code]

  def new
  end

  def create
    employee = Employee.find_active_by_national_id(login_params[:national_id])

    if employee&.password_login_enabled? && employee.authenticate(login_params[:password])
      sign_in_employee(employee, remember: remember_login?, installed_pwa: installed_pwa_login?)
    else
      flash.now[:alert] = t(".invalid")
      render :new, status: :unprocessable_entity
    end
  end

  def request_code
    delivery_method = requested_delivery_method

    unless Employee.valid_national_id?(code_request_params[:national_id])
      flash.now[:alert] = t(".invalid_national_id")
      render :new, status: :unprocessable_entity
      return
    end

    unless LoginCodeDeliveryConfig.configured?(delivery_method)
      notify_login_code_delivery_error(
        LoginCodeDeliveryConfig::ConfigurationError.new("#{delivery_method} login code delivery is not configured"),
        delivery_method: delivery_method
      )

      flash.now[:alert] = t(".delivery_unavailable.#{delivery_method}")
      render :new, status: :bad_gateway
      return
    end

    employee = Employee.find_active_by_national_id(code_request_params[:national_id])
    code_delivery_employee = employee if employee&.can_receive_login_code?(delivery_method)

    if code_delivery_employee && !code_delivery_employee.login_code_rate_limited?
      code = code_delivery_employee.generate_login_code!(delivery_method: delivery_method)
      deliver_login_code(code_delivery_employee, code, delivery_method)
    end

    store_pending_employee_login(
      code_delivery_employee,
      national_id: code_request_params[:national_id],
      delivery_method: delivery_method,
      remember: remember_login?,
      installed_pwa: installed_pwa_login?
    )

    redirect_to login_code_path
  end

  def code
    @delivery_method = pending_employee_login_delivery_method
  end

  def verify_code
    if @pending_employee&.authenticate_login_code(submitted_login_code)
      @pending_employee.clear_login_code!
      remember = pending_employee_login_remember?
      installed_pwa = pending_employee_login_installed_pwa?
      clear_pending_employee_login
      sign_in_employee(@pending_employee, remember: remember, installed_pwa: installed_pwa)
    else
      @delivery_method = pending_employee_login_delivery_method
      flash.now[:alert] = t(".invalid")
      render :code, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out_employee
    redirect_to login_path, notice: t(".signed_out")
  end

  private

  def login_params
    params.permit(:national_id, :password, :remember_me, :installed_pwa)
  end

  def code_request_params
    params.permit(:national_id, :delivery_method, :remember_me, :installed_pwa)
  end

  def verify_code_params
    params.permit(:code, code_digits: [])
  end

  def submitted_login_code
    verify_code_params[:code].presence || Array(verify_code_params[:code_digits]).join
  end

  def remember_login?
    ActiveModel::Type::Boolean.new.cast(params[:remember_me])
  end

  def installed_pwa_login?
    ActiveModel::Type::Boolean.new.cast(params[:installed_pwa])
  end

  def requested_delivery_method
    code_request_params[:delivery_method].presence_in(LoginCodeDeliveryConfig::DELIVERY_METHODS) || "email"
  end

  def deliver_login_code(employee, code, delivery_method)
    case delivery_method
    when "sms"
      SmsArena.deliver_login_code(phone: employee.phone, code: code)
    when "email"
      EmployeeLoginMailer.code(employee, code).deliver_now
    end

    true
  rescue StandardError => error
    employee.clear_login_code!
    notify_login_code_delivery_error(error, delivery_method: delivery_method, employee: employee)
  end

  def load_pending_employee_login
    return @pending_employee = pending_employee_login if pending_employee_login_requested?

    clear_pending_employee_login
    redirect_to login_path(delivery_method: "email"), alert: t("employee.sessions.flash.code_required")
  end

  def redirect_signed_in_employee
    redirect_to root_path if employee_signed_in?
  end

  def redirect_to_code_request_rate_limit
    redirect_to login_path(delivery_method: params[:delivery_method].presence || "email"),
      alert: t("employee.sessions.request_code.rate_limited")
  end

  def notify_login_code_delivery_error(error, delivery_method:, employee: nil)
    ErrorNotifier.notify(
      error,
      data: {
        context: "employee_login_code_delivery",
        delivery_method: delivery_method,
        employee_id: employee&.id
      }.compact
    )
  end
end
