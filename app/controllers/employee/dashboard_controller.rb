class Employee::DashboardController < ApplicationController
  layout "employee"

  def show
    @employee = demo_current_employee
    @today_clockings = demo_today_clockings
    @week_summary = {
      worked: "30 h 15 min",
      days: 4,
      corrections: 1
    }
    @pending_correction = demo_employee_corrections.find { |correction| correction[:status] == :pending }
  end
end
