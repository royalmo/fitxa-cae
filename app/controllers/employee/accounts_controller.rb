class Employee::AccountsController < ApplicationController
  layout "employee"

  def show
    @employee = current_employee
  end

  def update_contact
    @employee = current_employee

    if @employee.update(account_contact_params)
      redirect_to account_path, notice: t("employee.flash.account_updated")
    else
      @account_error_context = :contact
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    @employee = current_employee
    assign_password_change

    if @employee.errors.empty? && @employee.save
      redirect_to account_path, notice: t("employee.flash.account_updated")
    else
      @account_error_context = :password
      @password_panel_open = true
      render :show, status: :unprocessable_entity
    end
  end

  def contact_human_resources
    @employee = current_employee
    @hr_contact_form = hr_contact_params

    unless human_resources_contact_valid?
      flash.now[:hr_contact_alert] = t(".blank")
      render :show, status: :unprocessable_entity
      return
    end

    HumanResourcesContactMailer
      .contact_request(@employee, subject: @hr_contact_form[:subject], body: @hr_contact_form[:message])
      .deliver_later

    redirect_to account_path(anchor: "human_resources_contact"), flash: {
      hr_contact_notice: t(".sent")
    }
  rescue StandardError => error
    ErrorNotifier.notify(
      error,
      data: {
        employee_id: @employee&.id,
        subject: @hr_contact_form&.fetch(:subject, nil)
      }
    )
    flash.now[:hr_contact_alert] = t(".failed")
    render :show, status: :unprocessable_entity
  end

  private

  def account_contact_params
    params.permit(:email, :phone)
  end

  def account_password_params
    params.permit(:current_password, :password, :password_confirmation)
  end

  def hr_contact_params
    params.permit(:subject, :message).to_h.symbolize_keys
  end

  def human_resources_contact_valid?
    @hr_contact_form[:subject].present? && @hr_contact_form[:message].present?
  end

  def assign_password_change
    if account_password_params[:password].blank? && account_password_params[:password_confirmation].blank?
      @employee.errors.add(:base, t(".password_blank"))
      return
    end

    unless current_password_valid_for_change?
      @employee.errors.add(:base, t(".current_password_invalid"))
      return
    end

    if account_password_params[:password] != account_password_params[:password_confirmation]
      @employee.errors.add(:base, t(".password_confirmation_invalid"))
      return
    end

    @employee.password = account_password_params[:password]
  end

  def current_password_valid_for_change?
    return true unless @employee.password_login_enabled?

    @employee.authenticate(account_password_params[:current_password].to_s)
  end
end
