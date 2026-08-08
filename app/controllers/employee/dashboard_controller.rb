class Employee::DashboardController < ApplicationController
  include EmployeeClockingSummaries

  layout "employee"

  def show
    @employee = current_employee
    now = Time.current
    @today = now.in_time_zone.to_date
    @clock_state = current_clock_state(@employee, at: now)
    @today_swipes = @employee.swipes.kept.for_day(@today).chronological.to_a
    @today_worked_seconds = @clock_state[:worked_seconds]
    @today_summary = clocking_day_summaries(@employee, start_date: @today, end_date: @today).first || empty_today_summary
    @week_summary = week_clocking_summary(@employee, date: @today)
    @dashboard_refresh_signature = dashboard_refresh_signature(@clock_state, today: @today)
  end

  def state
    now = Time.current
    clock_state = current_clock_state(current_employee, at: now)

    expires_now

    render json: {
      signature: dashboard_refresh_signature(clock_state, today: now.in_time_zone.to_date)
    }
  end

  private

  def dashboard_refresh_signature(clock_state, today:)
    [
      today.iso8601,
      clock_state[:clocked_in],
      clock_state[:clocked_in_at]&.iso8601(6),
      clock_state[:worked_seconds].to_i
    ].join("|")
  end

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
