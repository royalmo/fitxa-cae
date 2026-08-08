class Employee::PasswordResetsController < ApplicationController
  CODE_REQUEST_RATE_LIMIT_STORE = Employee::SessionsController::CODE_REQUEST_RATE_LIMIT_STORE

  layout "employee_auth"

  skip_before_action :authenticate_employee!

  rate_limit to: 10,
    within: 5.minutes,
    only: :create,
    store: CODE_REQUEST_RATE_LIMIT_STORE,
    with: :redirect_to_password_reset_rate_limit

  before_action :redirect_signed_in_employee, only: %i[new create]
  before_action :load_pending_employee_password_reset, only: %i[code verify_code]
  before_action :load_pending_employee_password_setup, only: %i[edit update skip]

  def new
  end

  def create
    delivery_method = requested_delivery_method

    unless Employee.valid_national_id?(password_reset_params[:national_id])
      flash.now[:alert] = t(".invalid_national_id")
      render :new, status: :unprocessable_entity
      return
    end

    unless LoginCodeDeliveryConfig.configured?(delivery_method)
      notify_login_code_delivery_error(
        LoginCodeDeliveryConfig::ConfigurationError.new("#{delivery_method} password reset code delivery is not configured"),
        delivery_method: delivery_method
      )

      flash.now[:alert] = t(".delivery_unavailable.#{delivery_method}")
      render :new, status: :bad_gateway
      return
    end

    employee = Employee.find_active_by_national_id(password_reset_params[:national_id])
    code_delivery_employee = employee if employee&.can_receive_login_code?(delivery_method)

    if code_delivery_employee
      rate_limit_reason = code_delivery_employee.login_code_rate_limit_reason

      if rate_limit_reason
        log_login_code_rate_limited(code_delivery_employee, delivery_method, rate_limit_reason)
      else
        code = code_delivery_employee.generate_login_code!(delivery_method: delivery_method)
        deliver_login_code(code_delivery_employee, code, delivery_method)
      end
    end

    store_pending_employee_password_reset(
      code_delivery_employee,
      national_id: password_reset_params[:national_id],
      delivery_method: delivery_method
    )

    redirect_to employee_password_reset_code_path
  end

  def code
    @delivery_method = pending_employee_password_reset_delivery_method
  end

  def verify_code
    if @pending_employee&.authenticate_login_code(submitted_login_code)
      @pending_employee.clear_login_code!
      clear_pending_employee_password_reset
      store_pending_employee_password_setup(@pending_employee, reason: "reset", remember: false, installed_pwa: false)
      redirect_to edit_employee_password_reset_path
    else
      @delivery_method = pending_employee_password_reset_delivery_method
      flash.now[:alert] = t(".invalid")
      render :code, status: :unprocessable_entity
    end
  end

  def edit
    flash.now[:notice] = t(".first_login_notice") if pending_employee_password_setup_first_login?
  end

  def update
    assign_password_setup

    if @employee.errors.empty? && @employee.save
      remember = pending_employee_password_setup_remember?
      installed_pwa = pending_employee_password_setup_installed_pwa?
      clear_pending_employee_password_setup
      sign_in_employee(
        @employee,
        remember: remember,
        installed_pwa: installed_pwa,
        redirect_path: root_path,
        notice: t(".success")
      )
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def skip
    unless pending_employee_password_setup_first_login?
      redirect_to edit_employee_password_reset_path
      return
    end

    remember = pending_employee_password_setup_remember?
    installed_pwa = pending_employee_password_setup_installed_pwa?
    clear_pending_employee_password_setup
    sign_in_employee(@employee, remember: remember, installed_pwa: installed_pwa, redirect_path: root_path)
  end

  private

  def password_reset_params
    params.permit(:national_id, :delivery_method)
  end

  def verify_code_params
    params.permit(:code, code_digits: [])
  end

  def password_setup_params
    params.permit(:password, :password_confirmation)
  end

  def requested_delivery_method
    password_reset_params[:delivery_method].presence_in(LoginCodeDeliveryConfig::DELIVERY_METHODS) || "email"
  end

  def submitted_login_code
    verify_code_params[:code].presence || Array(verify_code_params[:code_digits]).join
  end

  def assign_password_setup
    if password_setup_params[:password].blank? && password_setup_params[:password_confirmation].blank?
      @employee.errors.add(:base, t(".password_blank"))
      return
    end

    if password_setup_params[:password] != password_setup_params[:password_confirmation]
      @employee.errors.add(:base, t(".password_confirmation_invalid"))
      return
    end

    @employee.password = password_setup_params[:password]
  end

  def load_pending_employee_password_reset
    return @pending_employee = pending_employee_password_reset if pending_employee_password_reset_requested?

    clear_pending_employee_password_reset
    redirect_to new_employee_password_reset_path(delivery_method: "email"), alert: t("employee.password_resets.flash.code_required")
  end

  def load_pending_employee_password_setup
    @employee = pending_employee_password_setup
    return if @employee

    clear_pending_employee_password_setup
    redirect_to_password_setup_required
  end

  def redirect_signed_in_employee
    redirect_to root_path if employee_signed_in?
  end

  def redirect_to_password_setup_required
    if employee_signed_in?
      redirect_to root_path
    else
      redirect_to login_path, alert: t("employee.password_resets.flash.password_setup_required")
    end
  end

  def redirect_to_password_reset_rate_limit
    redirect_to new_employee_password_reset_path(delivery_method: params[:delivery_method].presence || "email"),
      alert: t("employee.password_resets.create.rate_limited")
  end

  def deliver_login_code(employee, code, delivery_method)
    EmployeeLoginCodeDeliveryJob.perform_later(employee, code, delivery_method)
    true
  rescue StandardError => error
    employee.clear_login_code!
    notify_login_code_delivery_error(error, delivery_method: delivery_method, employee: employee)
  end

  def log_login_code_rate_limited(employee, delivery_method, reason)
    Rails.logger.info(
      "Login code delivery skipped: employee rate limit active " \
      "(context=employee_password_reset_code_delivery employee_id=#{employee.id} " \
      "delivery_method=#{delivery_method} reason=#{reason})"
    )
  end

  def notify_login_code_delivery_error(error, delivery_method:, employee: nil)
    ErrorNotifier.notify(
      error,
      data: {
        context: "employee_password_reset_code_delivery",
        delivery_method: delivery_method,
        employee_id: employee&.id
      }.compact
    )
  end

  def store_pending_employee_password_reset(employee, national_id:, delivery_method:)
    session[:pending_employee_password_reset] = {
      "employee_id" => employee&.id,
      "national_id" => Employee.normalize_national_id(national_id),
      "delivery_method" => delivery_method
    }
  end

  def pending_employee_password_reset
    Employee.find_by(id: pending_employee_password_reset_state["employee_id"], active: true) if pending_employee_password_reset_state["employee_id"]
  end

  def clear_pending_employee_password_reset
    session.delete(:pending_employee_password_reset)
  end

  def pending_employee_password_reset_delivery_method
    pending_employee_password_reset_state["delivery_method"].presence || "email"
  end

  def pending_employee_password_reset_state
    session[:pending_employee_password_reset] || {}
  end

  def pending_employee_password_reset_requested?
    pending_employee_password_reset_state.present?
  end
end
