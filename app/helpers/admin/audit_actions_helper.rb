module Admin::AuditActionsHelper
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
end
