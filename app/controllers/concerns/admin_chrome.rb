module AdminChrome
  extend ActiveSupport::Concern

  include EmployeeClockingSummaries

  private

  def set_admin_current_manager
    @admin_current_manager = current_manager
  end

  def set_admin_topbar
    @admin_pending_corrections_count = SwipeCorrection.pending.count
    @admin_pending_corrections_badge = @admin_pending_corrections_count > 99 ? "99+" : @admin_pending_corrections_count.to_s
    @admin_employee_shortcut = @admin_current_manager.employee if @admin_current_manager&.employee&.active?
    @admin_employee_shortcut_working = current_clock_state(@admin_employee_shortcut)[:clocked_in] if @admin_employee_shortcut
  end
end
