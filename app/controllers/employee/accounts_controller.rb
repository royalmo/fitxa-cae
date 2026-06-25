class Employee::AccountsController < ApplicationController
  layout "employee"

  def show
    @employee = demo_current_employee
  end

  def update
    redirect_to account_path, notice: t("employee.flash.account_updated")
  end
end
