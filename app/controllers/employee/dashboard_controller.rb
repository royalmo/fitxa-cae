class Employee::DashboardController < ApplicationController
  layout "employee"

  def show
    @employee = demo_current_employee
    @today_clockings = demo_today_clockings
    @week_summary = {
      worked: "30 h 15 min",
      expected: "37 h 30 min",
      balance: "-7 h 15 min",
      progress: 81
    }
    @pending_correction = demo_employee_corrections.find { |correction| correction[:status] == :pending }
  end
end
