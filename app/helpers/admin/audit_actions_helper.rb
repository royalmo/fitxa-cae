module Admin::AuditActionsHelper
  AUDIT_ACTION_DETAIL_MESSAGE_KEYS = %w[message detail details_text].freeze

  def admin_audit_actions_month_options
    I18n.t("date.month_names").each_with_index.filter_map do |month_name, month_number|
      [ month_name, month_number ] if month_number.positive?
    end
  end

  def admin_audit_author_kind_filter_label(author_type)
    t("admin.audit_actions.index.author_kind_filters.#{admin_audit_author_kind_filter_key(author_type)}")
  end

  def admin_audit_author_kind_filter_icon(author_type)
    case author_type
    when "Employee"
      "user"
    when "Manager"
      "user-cog"
    else
      "users"
    end
  end

  def admin_audit_subject_text(record)
    case record
    when Employee
      employee_display_name(record)
    when Manager
      manager_display_name(record)
    else
      record.to_s
    end
  end

  def admin_audit_action_kind_text(kind)
    t("admin.audit_actions.kinds.#{kind}", default: kind.to_s.tr("._", " ").humanize)
  end

  def admin_audit_author_value(author)
    "#{author.class.name}:#{author.id}"
  end

  def admin_audit_author_icon(author)
    author.is_a?(Manager) ? "user-cog" : "user"
  end

  def admin_audit_subject_path(record)
    case record
    when Employee
      edit_admin_employee_path(record)
    when Manager
      edit_admin_manager_path(record)
    end
  end

  def admin_audit_action_modal_id(audit_action)
    "admin_audit_action_modal_#{audit_action.id}"
  end

  def admin_audit_action_detail_text(audit_action)
    custom_detail = admin_audit_action_custom_detail(audit_action)
    return custom_detail if custom_detail.present?

    case audit_action.kind
    when "employee.updated", "manager.updated"
      admin_audit_update_detail_text(audit_action)
    when "swipe_correction.created", "swipe_correction.updated",
         "swipe_correction.approved", "swipe_correction.rejected"
      admin_audit_correction_detail_text(audit_action)
    else
      t("admin.audit_actions.details.default",
        kind: admin_audit_action_kind_text(audit_action.kind),
        recipient_name: admin_audit_subject_text(audit_action.recipient))
    end
  end

  def admin_audit_action_raw_details(audit_action)
    details = audit_action.extra_info.presence || {}

    JSON.pretty_generate(details)
  rescue JSON::GeneratorError
    details.to_s
  end

  def admin_audit_author_secondary_text(author)
    case author
    when Employee
      author.national_id
    when Manager
      author.email
    end
  end

  private

  def admin_audit_author_kind_filter_key(author_type)
    case author_type
    when "Employee"
      "employees"
    when "Manager"
      "managers"
    else
      "all"
    end
  end

  def admin_audit_update_detail_text(audit_action)
    field = admin_audit_extra_value(audit_action, "field").to_s

    return admin_audit_password_detail_text(audit_action) if field.in?(%w[password password_digest])
    return admin_audit_active_detail_text(audit_action) if field == "active"

    if field.present?
      t("admin.audit_actions.details.updated.field",
        field: admin_audit_field_text(field),
        recipient_name: admin_audit_subject_text(audit_action.recipient))
    elsif audit_action.recipient.is_a?(Manager)
      t("admin.audit_actions.details.updated.manager",
        recipient_name: admin_audit_subject_text(audit_action.recipient))
    else
      t("admin.audit_actions.details.updated.employee",
        recipient_name: admin_audit_subject_text(audit_action.recipient))
    end
  end

  def admin_audit_password_detail_text(audit_action)
    t("admin.audit_actions.details.updated.password",
      recipient_name: admin_audit_subject_text(audit_action.recipient))
  end

  def admin_audit_active_detail_text(audit_action)
    active = admin_audit_boolean_value(admin_audit_extra_value(audit_action, "active", "new_value", "value", "to"))
    recipient = audit_action.recipient

    if active == false
      key = recipient.is_a?(Manager) ? "manager_disabled" : "employee_disabled"
    elsif active == true
      key = recipient.is_a?(Manager) ? "manager_enabled" : "employee_enabled"
    else
      key = "field"
    end

    t("admin.audit_actions.details.updated.#{key}",
      field: admin_audit_field_text("active"),
      recipient_name: admin_audit_subject_text(recipient))
  end

  def admin_audit_correction_detail_text(audit_action)
    status_key = audit_action.kind.to_s.split(".").last
    day = admin_audit_action_day_text(audit_action)
    translation_key = day.present? ? "#{status_key}_with_day" : status_key

    t("admin.audit_actions.details.swipe_correction.#{translation_key}",
      recipient_name: admin_audit_subject_text(audit_action.recipient),
      day: day,
      default: t("admin.audit_actions.details.swipe_correction.default",
        kind: admin_audit_action_kind_text(audit_action.kind),
        recipient_name: admin_audit_subject_text(audit_action.recipient)))
  end

  def admin_audit_action_custom_detail(audit_action)
    AUDIT_ACTION_DETAIL_MESSAGE_KEYS.each do |key|
      value = admin_audit_extra_value(audit_action, key)
      return value if value.is_a?(String) && value.present?
    end

    nil
  end

  def admin_audit_action_day_text(audit_action)
    value = admin_audit_extra_value(audit_action, "day", "date", "correction_day", "requested_day")
    date = Date.parse(value.to_s) if value.present?

    l(date, format: :long) if date
  rescue Date::Error
    value.to_s
  end

  def admin_audit_extra_value(audit_action, *keys)
    details = audit_action.extra_info || {}
    keys.each do |key|
      value = details[key] || details[key.to_sym]
      return value unless value.nil?
    end

    nil
  end

  def admin_audit_boolean_value(value)
    return value if value == true || value == false

    case value.to_s
    when "true", "1" then true
    when "false", "0" then false
    end
  end

  def admin_audit_field_text(field)
    t("admin.audit_actions.fields.#{field}", default: field.to_s.humanize.downcase)
  end
end
