module Admin::EmployeesHelper
  def admin_employee_status(employee)
    employee.active? ? :active : :disabled
  end

  def admin_employee_tags(employee)
    employee.tags.any? ? employee.tags.map(&:name).join(", ") : t("admin.employees.index.no_tags")
  end

  def admin_last_clocking_text(employee, last_swipes_by_employee_id)
    swipe = last_swipes_by_employee_id[employee.id]
    return t("admin.employees.index.no_clockings") unless swipe

    "#{clocking_kind_text(swipe.kind)} #{l(swipe.swipe_at, format: :short)}"
  end
end
