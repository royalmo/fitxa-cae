class Employee::DashboardController < ApplicationController
  include EmployeeClockingSummaries

  layout "employee"

  def show
    @employee = current_employee
    @clock_state = current_clock_state(@employee)
    @today_swipes = @employee.swipes.kept.for_day(Time.zone.today).chronological
    @week_summary = week_clocking_summary(@employee)
  end
end
