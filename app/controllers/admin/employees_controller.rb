class Admin::EmployeesController < ApplicationController
  layout "admin"

  def index
    @manager = demo_current_manager
    @employees = demo_employees
  end

  def new
    @manager = demo_current_manager
    @employee = {
      code: "EMP-032",
      name: "",
      email: "",
      team: "",
      schedule: "09:00-17:00",
      status: :active
    }
  end

  def create
    redirect_to admin_employees_path, notice: t("admin.flash.employee_created")
  end

  def edit
    @manager = demo_current_manager
    @employee = demo_employees.find { |employee| employee[:id].to_s == params[:id] } || demo_employees.first
  end

  def update
    redirect_to admin_employees_path, notice: t("admin.flash.employee_updated")
  end
end
