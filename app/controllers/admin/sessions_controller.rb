class Admin::SessionsController < ApplicationController
  PASSWORD_LOGIN_RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  layout "admin_auth"

  rate_limit to: 10,
    within: 5.minutes,
    only: :create,
    store: PASSWORD_LOGIN_RATE_LIMIT_STORE,
    with: :redirect_to_password_login_rate_limit

  before_action :redirect_signed_in_manager, only: :new

  def new
  end

  def create
    manager = Manager.find_active_by_email(login_params[:email])

    if manager&.authenticate_password(login_params[:password])
      sign_in_manager(manager, remember: remember_login?)
    else
      flash.now[:alert] = t(".invalid")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out_manager
    redirect_to admin_login_path, notice: t(".signed_out")
  end

  private

  def login_params
    params.permit(:email, :password, :remember_me)
  end

  def remember_login?
    ActiveModel::Type::Boolean.new.cast(login_params[:remember_me])
  end

  def redirect_signed_in_manager
    redirect_to admin_root_path if manager_signed_in?
  end

  def redirect_to_password_login_rate_limit
    redirect_to admin_login_path, alert: t("admin.sessions.create.rate_limited")
  end
end
