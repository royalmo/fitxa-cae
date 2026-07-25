class Admin::BaseController < ApplicationController
  include AdminPagination
  include EmployeeClockingSummaries

  layout "admin"

  before_action :authenticate_manager!
  before_action :set_manager
  before_action :set_admin_topbar

  private

  def set_manager
    @manager = current_manager
  end

  def set_admin_topbar
    @admin_pending_corrections_count = SwipeCorrection.pending.count
    @admin_pending_corrections_badge = @admin_pending_corrections_count > 99 ? "99+" : @admin_pending_corrections_count.to_s
    @admin_employee_shortcut = @manager.employee if @manager&.employee&.active?
    @admin_employee_shortcut_working = current_clock_state(@admin_employee_shortcut)[:clocked_in] if @admin_employee_shortcut
  end
end
