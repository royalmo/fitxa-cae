class Admin::AuditActionsController < Admin::BaseController
  AUDIT_ACTIONS_PER_PAGE = 30

  def index
    @audit_actions = paginate_admin_relation(
      filtered_audit_actions.order(created_at: :desc, id: :desc),
      per_page: AUDIT_ACTIONS_PER_PAGE
    ).includes(:author, :recipient).to_a
  end

  def export
    require "csv"

    audit_actions = filtered_audit_actions
      .order(created_at: :desc, id: :desc)
      .includes(:author, :recipient)
      .limit(10_000)

    send_data audit_actions_csv(audit_actions),
      filename: "fitxa-cae-activitat-#{Time.zone.today.strftime("%Y%m%d")}.csv",
      type: "text/csv; charset=utf-8"
  end

  private

  def filtered_audit_actions
    audit_actions = AuditAction.all
    audit_actions = audit_actions.where(kind: params[:kind]) if params[:kind].present?
    audit_actions
  end

  def audit_actions_csv(audit_actions)
    CSV.generate(headers: true) do |csv|
      csv << [
        t("admin.audit_actions.index.created_at"),
        t("admin.audit_actions.index.kind"),
        t("admin.audit_actions.index.author"),
        t("admin.audit_actions.index.recipient"),
        t("admin.audit_actions.index.extra_info")
      ]

      audit_actions.each do |audit_action|
        csv << [
          I18n.l(audit_action.created_at, format: :short),
          audit_action.kind,
          audit_subject_text(audit_action.author),
          audit_subject_text(audit_action.recipient),
          audit_action.extra_info
        ]
      end
    end
  end

  def audit_subject_text(record)
    case record
    when Employee
      record.full_name.presence || record.first_name.presence || t("employee.guest")
    when Manager
      record.full_name.presence || record.email.presence || t("admin.guest")
    else
      record.to_s
    end
  end
end
