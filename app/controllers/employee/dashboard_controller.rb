class Employee::DashboardController < ApplicationController
  include EmployeeClockingSummaries

  layout "employee"

  def show
    @employee = current_employee
    @today = Time.zone.today
    @clock_state = current_clock_state(@employee)
    @today_swipes = @employee.swipes.kept.for_day(@today).chronological.to_a
    @today_worked_seconds = Swipe.paired_work_seconds(@today_swipes)
    @today_summary = clocking_day_summaries(@employee, start_date: @today, end_date: @today).first || empty_today_summary
    @week_summary = week_clocking_summary(@employee, date: @today)
  end

  private

  def empty_today_summary
    {
      date: @today,
      entry_at: nil,
      exit_at: nil,
      swipes_count: 0,
      swipes: [],
      worked_seconds: 0,
      status: :empty
    }
  end
end
