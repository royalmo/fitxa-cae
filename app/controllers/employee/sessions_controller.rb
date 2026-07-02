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
    delivery_method = code_request_params[:delivery_method].to_s
    employee = Employee.find_active_by_national_id(code_request_params[:national_id])

    unless employee&.can_receive_login_code?(delivery_method)
      flash.now[:alert] = t(".unavailable")
      render :new, status: :unprocessable_entity
      return
    end

    if employee.login_code_rate_limited?
      flash.now[:alert] = t(".rate_limited")
      render :new, status: :too_many_requests
      return
    end

    code = employee.generate_login_code!(delivery_method: delivery_method)
    unless deliver_login_code(employee, code, delivery_method)
      employee.clear_login_code!
      flash.now[:alert] = t(".delivery_failed")
      render :new, status: :bad_gateway
      return
    end

    store_pending_employee_login(
      employee,
      delivery_method: delivery_method,
      remember: remember_login?,
      installed_pwa: installed_pwa_login?
    )

    redirect_to login_code_path, notice: t(".sent")
  end

  def code
    @delivery_method = pending_employee_login_delivery_method
    @masked_destination = masked_destination(@pending_employee, @delivery_method)
  end

  def verify_code
    if @pending_employee.authenticate_login_code(params[:code])
      @pending_employee.clear_login_code!
      remember = pending_employee_login_remember?
      installed_pwa = pending_employee_login_installed_pwa?
      clear_pending_employee_login
      sign_in_employee(@pending_employee, remember: remember, installed_pwa: installed_pwa)
    else
      @delivery_method = pending_employee_login_delivery_method
      @masked_destination = masked_destination(@pending_employee, @delivery_method)
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

  def remember_login?
    ActiveModel::Type::Boolean.new.cast(params[:remember_me])
  end

  def installed_pwa_login?
    ActiveModel::Type::Boolean.new.cast(params[:installed_pwa])
  end

  def deliver_login_code(employee, code, delivery_method)
    case delivery_method
    when "sms"
      SmsArena.deliver_login_code(phone: employee.phone, code: code)
    when "email"
      EmployeeLoginMailer.code(employee, code).deliver_now
    end

    true
  rescue SmsArena::Error => error
    Rails.logger.warn("SMSArena login code delivery failed: #{error.class}: #{error.message}")
    false
  end

  def load_pending_employee_login
    @pending_employee = pending_employee_login
    return if @pending_employee

    clear_pending_employee_login
    redirect_to login_path, alert: t("employee.sessions.flash.code_required")
  end

  def redirect_signed_in_employee
    redirect_to root_path if employee_signed_in?
  end

  def redirect_to_code_request_rate_limit
    redirect_to login_path, alert: t("employee.sessions.request_code.rate_limited")
  end

  def masked_destination(employee, delivery_method)
    case delivery_method
    when "sms"
      employee.phone.to_s.sub(/\d(?=\d{3})/, "*")
    when "email"
      email = employee.email.to_s
      local, domain = email.split("@", 2)
      "#{local.first}***@#{domain}"
    end
  end
end
