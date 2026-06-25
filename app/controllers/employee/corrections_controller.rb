class Employee::CorrectionsController < ApplicationController
  layout "employee"

  def index
    @employee = demo_current_employee
    @corrections = demo_employee_corrections
  end

  def new
    @employee = demo_current_employee
  end

  def create
    redirect_to corrections_path, notice: t("employee.flash.correction_requested")
  end
end
