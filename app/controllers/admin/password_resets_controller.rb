class Admin::PasswordResetsController < ApplicationController
  layout "admin_auth"

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
    return reset_manager if reset_manager&.active?

    Manager.find_by_password_setup_token(params[:token])
  end

  def redirect_signed_in_manager
    redirect_to admin_root_path if manager_signed_in?
  end
end
