class Admin::PasswordResetsController < ApplicationController
  PASSWORD_RESET_RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  layout "admin_auth"

  rate_limit to: 10,
    within: 5.minutes,
    only: :create,
    store: PASSWORD_RESET_RATE_LIMIT_STORE,
    with: :redirect_to_password_reset_rate_limit

  before_action :redirect_signed_in_manager, only: %i[new create]
  before_action :load_manager_from_token, only: %i[edit update]

  def new
  end

  def create
    manager = Manager.find_active_by_email(password_reset_request_params[:email])
    ManagerPasswordMailer.password_reset(manager).deliver_later if manager

    redirect_to admin_login_path, notice: t(".sent")
  end

  def edit
  end

  def update
    assign_password

    if @manager.errors.empty? && @manager.save
      record_manager_password_change_audit(@manager, origin: @password_change_origin || "password_reset")
      sign_out_manager
      redirect_to admin_login_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_reset_request_params
    params.permit(:email)
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end

  def assign_password
    if password_params[:password].blank? && password_params[:password_confirmation].blank?
      @manager.errors.add(:base, t(".password_blank"))
      return
    end

    if password_params[:password] != password_params[:password_confirmation]
      @manager.errors.add(:base, t(".password_confirmation_invalid"))
      return
    end

    @manager.password = password_params[:password]
  end

  def load_manager_from_token
    @manager = manager_from_token
    redirect_to new_admin_password_reset_path, alert: t("admin.password_resets.flash.invalid_token") unless @manager
  end

  def manager_from_token
    reset_manager = Manager.find_by_password_reset_token(params[:token])
    if reset_manager&.active?
      @password_change_origin = "password_reset"
      return reset_manager
    end

    setup_manager = Manager.find_by_password_setup_token(params[:token])
    @password_change_origin = "first_time" if setup_manager
    setup_manager
  end

  def redirect_signed_in_manager
    redirect_to admin_root_path if manager_signed_in?
  end

  def redirect_to_password_reset_rate_limit
    redirect_to new_admin_password_reset_path, alert: t("admin.password_resets.create.rate_limited")
  end

  def record_manager_password_change_audit(manager, origin:)
    record_audit_action!(
      author: manager,
      recipient: manager,
      kind: "manager.password_changed",
      extra_info: {
        changed_fields: [ "password" ],
        origin: origin
      }
    )
  end
end
