class Admin::DashboardController < ApplicationController
  layout "admin"

  def index
    @manager = demo_current_manager
    @stats = demo_admin_stats
    @employees = demo_employees
    @corrections = demo_admin_corrections
  end
end
