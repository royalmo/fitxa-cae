class Employee::ClockingsController < ApplicationController
  include EmployeeClockingSummaries

  layout "employee"

  def index
    @employee = current_employee
    @month = Time.zone.today
    @clocking_days = clocking_day_summaries(
      @employee,
      start_date: @month.beginning_of_month,
      end_date: @month
    )
  end

  def clock_in
    if current_employee.clocked_in?
      redirect_to root_path, alert: t("employee.flash.already_clocked_in")
      return
    end

    current_employee.swipes.create!(
      swipe_at: Time.current,
      kind: :entry,
      metadata: "employee_portal"
    )

    redirect_to root_path, notice: t("employee.flash.clocked_in")
  end

  def clock_out
    unless current_employee.clocked_in?
      redirect_to root_path, alert: t("employee.flash.already_clocked_out")
      return
    end

    current_employee.swipes.create!(
      swipe_at: Time.current,
      kind: :exit,
      metadata: "employee_portal"
    )

    redirect_to root_path, notice: t("employee.flash.clocked_out")
  end
end
