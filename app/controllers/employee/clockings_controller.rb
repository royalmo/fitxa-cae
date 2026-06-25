class Employee::ClockingsController < ApplicationController
  layout "employee"

  def index
    @employee = demo_current_employee
    @clocking_days = demo_clocking_days
  end

  def clock_in
    redirect_to root_path, notice: t("employee.flash.clocked_in")
  end

  def clock_out
    redirect_to root_path, notice: t("employee.flash.clocked_out")
  end
end
