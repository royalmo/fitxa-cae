module Admin::EmployeesHelper
  def admin_employee_status(employee)
    employee.active? ? :active : :disabled
  end

  def admin_employee_status_icon(employee)
    employee.active? ? "circle-check" : "circle-off"
  end

  def admin_employee_status_icon_class(employee)
    class_names(
      "admin-employee-status-icon",
      "is-active": employee.active?,
      "is-inactive": !employee.active?
    )
  end

  def admin_employee_activation_action(employee)
    employee.active? ? :deactivate : :activate
  end

  def admin_employee_activation_icon(employee)
    employee.active? ? "circle-off" : "circle-check"
  end

  def admin_employee_activation_modal_id(employee)
    "employee_activation_modal_#{employee.id}"
  end

  def admin_employee_activation_button_class(employee)
    class_names(
      "btn btn-sm admin-row-action",
      employee.active? ? "btn-outline-secondary" : "btn-outline-success"
    )
  end

  def admin_employee_activation_submit_class(action)
    class_names("btn", action.to_sym == :deactivate ? "btn-danger" : "btn-primary")
  end

  def admin_employee_error_message(employee, error)
    duplicate_employee = admin_duplicate_employee_for_error(employee, error)
    return error.full_message unless duplicate_employee

    safe_join([
      Employee.human_attribute_name(error.attribute),
      " ",
      t("admin.employees.form.duplicate_field_prefix"),
      " ",
      link_to(t("admin.employees.form.duplicate_field_link_text"), edit_admin_employee_path(duplicate_employee))
    ])
  end

  def admin_employee_empty_value(css_class: nil)
    tag.span("-", class: class_names("admin-employee-empty-value", css_class, "text-body-secondary"))
  end

  def admin_last_clocking_pill(employee, last_swipes_by_employee_id)
    swipe = last_swipes_by_employee_id[employee.id]
    return admin_employee_empty_value(css_class: "admin-employee-last-clocking-empty") unless swipe

    kind_text = clocking_kind_text(swipe.kind)
    label = "#{kind_text} #{l(swipe.swipe_at.to_date, format: :numeric)} #{l(swipe.swipe_at, format: :hour_minute)}"

    tag.span(
      class: class_names("admin-employee-last-clocking", "is-#{swipe.kind}"),
      title: label,
      aria: { label: label }
    ) do
      safe_join([
        icon(clocking_icon_name(swipe.kind), title: kind_text, class: "admin-employee-last-clocking-icon"),
        tag.span(l(swipe.swipe_at.to_date, format: :numeric), class: "admin-employee-last-clocking-date"),
        tag.span(l(swipe.swipe_at, format: :hour_minute), class: "admin-employee-last-clocking-time")
      ], " ")
    end
  end

  private

  def admin_duplicate_employee_for_error(employee, error)
    return unless error.type == :taken
    return unless error.attribute.in?(%i[national_id email])

    admin_duplicate_employee_for_attribute(employee, error.attribute)
  end

  def admin_duplicate_employee_for_attribute(employee, attribute)
    duplicate_scope = Employee.all
    duplicate_scope = duplicate_scope.where.not(id: employee.id) if employee.persisted?

    case attribute
    when :national_id
      national_id = Employee.normalize_national_id(employee.national_id)
      duplicate_scope.find_by(national_id: national_id) if national_id
    when :email
      email = Employee.normalize_email(employee.email)
      duplicate_scope.where("LOWER(email) = ?", email).first if email
    end
  end
end
