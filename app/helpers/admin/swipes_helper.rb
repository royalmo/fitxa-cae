module Admin::SwipesHelper
  def admin_correction_day_path(employee, day, correction = nil)
    return edit_admin_correction_path(correction) if correction

    new_admin_correction_path(employee_id: employee.id, day: day.iso8601)
  end

  def admin_clocking_status_text(status)
    status_text(status)
  end
end
