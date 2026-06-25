class Admin::ReportsController < ApplicationController
  layout "admin"

  def index
    @manager = demo_current_manager
    @report_rows = demo_report_rows
  end
end
