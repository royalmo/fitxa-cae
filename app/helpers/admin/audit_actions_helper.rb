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
end
