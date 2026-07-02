class Employee::AccountsController < ApplicationController
  layout "employee"

  def show
    @employee = current_employee
  end

  def update
    @employee = current_employee
    @employee.assign_attributes(account_contact_params)
    assign_password_change

    if @employee.errors.empty? && @employee.save
      redirect_to account_path, notice: t("employee.flash.account_updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.permit(:email, :phone, :current_password, :password, :password_confirmation)
  end

  def account_contact_params
    account_params.slice(:email, :phone)
  end

  def assign_password_change
    return if account_params[:password].blank? && account_params[:password_confirmation].blank?

    unless current_password_valid_for_change?
      @employee.errors.add(:base, t(".current_password_invalid"))
      return
    end

    if account_params[:password] != account_params[:password_confirmation]
      @employee.errors.add(:base, t(".password_confirmation_invalid"))
      return
    end

    @employee.password = account_params[:password]
  end

  def current_password_valid_for_change?
    return true unless @employee.password_login_enabled?

    @employee.authenticate(account_params[:current_password].to_s)
  end
end
