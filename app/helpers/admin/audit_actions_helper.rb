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
    t("admin.audit_actions.kinds.#{kind}", default: kind.to_s.tr("._", " ").humanize)
  end

  def admin_audit_author_value(author)
    "#{author.class.name}:#{author.id}"
  end

  def admin_audit_author_icon(author)
    author.is_a?(Manager) ? "user-cog" : "user"
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
end
