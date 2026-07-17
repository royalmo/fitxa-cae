class Admin::SessionsController < ApplicationController
  layout "admin_auth"

  before_action :redirect_signed_in_manager, only: :new

  def new
  end

  def create
    manager = Manager.find_active_by_email(login_params[:email])

    if manager&.authenticate_password(login_params[:password])
      sign_in_manager(manager)
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
    params.permit(:email, :password)
  end

  def redirect_signed_in_manager
    redirect_to admin_root_path if manager_signed_in?
  end
end
