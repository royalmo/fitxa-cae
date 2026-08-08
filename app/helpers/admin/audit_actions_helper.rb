module Admin::AuditActionsHelper
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
    t("audit_actions_texts.#{kind}.name", default: kind.to_s.tr("._", " ").humanize)
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
    t("audit_actions_texts.#{audit_action.kind}.description",
      **admin_audit_action_interpolations(audit_action),
      default: t("audit_actions_texts.default.description",
        kind: admin_audit_action_kind_text(audit_action.kind),
        recipient_name: admin_audit_subject_text(audit_action.recipient)))
  rescue I18n::MissingInterpolationArgument
    t("audit_actions_texts.default.description",
      kind: admin_audit_action_kind_text(audit_action.kind),
      recipient_name: admin_audit_subject_text(audit_action.recipient))
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

  def admin_audit_action_interpolations(audit_action)
    details = audit_action.extra_info || {}
    changed_fields = Array(details["changed_fields"]).compact_blank
    changed_fields = [ details["field"] ] if changed_fields.blank? && details["field"].present?

    {
      author_name: admin_audit_subject_text(audit_action.author),
      recipient_name: admin_audit_subject_text(audit_action.recipient),
      fields: admin_audit_fields_text(changed_fields),
      field: admin_audit_field_text(changed_fields.first),
      day: admin_audit_action_day_text(audit_action),
      origin: admin_audit_origin_text(details["origin"]),
      tag_name: details["tag_name"].to_s,
      report_kind: admin_audit_report_kind_text(details["report_kind"]),
      report_format: details["format"].to_s.upcase,
      period: details["period"].to_s,
      subject: details["subject"].to_s,
      bulk_action_kind: admin_audit_bulk_action_kind_text(details["bulk_action_kind"]),
      bulk_action: admin_audit_bulk_action_text(details["action"]),
      count: admin_audit_count_text(details),
      exported_count: details["exported_count"].to_i,
      filename: details["filename"].to_s
    }
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

  def admin_audit_field_text(field)
    return "" if field.blank?

    t("audit_actions_texts.fields.#{field}", default: field.to_s.humanize.downcase)
  end

  def admin_audit_fields_text(fields)
    Array(fields).compact_blank.map { |field| admin_audit_field_text(field) }.join(", ")
  end

  def admin_audit_origin_text(origin)
    return "" if origin.blank?

    t("audit_actions_texts.origins.#{origin}", default: origin.to_s.tr("_", " ").humanize.downcase)
  end

  def admin_audit_report_kind_text(report_kind)
    return "" if report_kind.blank?

    t("audit_actions_texts.report_kinds.#{report_kind}", default: report_kind.to_s.tr("_", " ").humanize.downcase)
  end

  def admin_audit_bulk_action_kind_text(kind)
    return "" if kind.blank?

    t("audit_actions_texts.bulk_action_kinds.#{kind}", default: kind.to_s.tr("_", " ").humanize.downcase)
  end

  def admin_audit_bulk_action_text(action)
    return "" if action.blank?

    t("audit_actions_texts.bulk_actions.#{action}", default: action.to_s.tr("_", " ").humanize.downcase)
  end

  def admin_audit_count_text(details)
    count = details["exported_count"] ||
      details["affected_count"] ||
      details["affected_national_id_count"] ||
      details["requested_swipe_count"] ||
      details["invalidated_swipe_count"]

    count.to_i
  end
end
