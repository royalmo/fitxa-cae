class Admin::AuditActionsController < Admin::BaseController
  AUDIT_ACTIONS_PER_PAGE = 30
  AUTHOR_TYPES = %w[Employee Manager].freeze

  def index
    load_filter_state

    @audit_actions = paginate_admin_relation(
      filtered_audit_actions.order(created_at: :desc, id: :desc),
      per_page: AUDIT_ACTIONS_PER_PAGE
    ).includes(:author, :recipient).to_a
  end

  def export
    require "csv"

    load_filter_state

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
    audit_actions = audit_actions.where(author_type: @selected_author_type) if selected_author_type?
    audit_actions = audit_actions.where(author: @selected_author) if @selected_author
    audit_actions = audit_actions.where(recipient: @selected_recipient) if @selected_recipient
    audit_actions = audit_actions.where(kind: params[:kind]) if params[:kind].present?
    filter_audit_actions_by_period(audit_actions)
  end

  def load_filter_state
    @selected_author_type = selected_author_type
    @selected_author = selected_author
    @selected_recipient = selected_recipient
    @selected_kind = params[:kind].presence
    @selected_month = selected_month
    @selected_year = selected_year
    @year_options = audit_year_options
  end

  def selected_author_type
    params[:author_type].presence_in(AUTHOR_TYPES)
  end

  def selected_author_type?
    @selected_author_type.present?
  end

  def selected_author
    selected_audit_subject(params[:author])
  end

  def selected_recipient
    selected_audit_subject(params[:recipient])
  end

  def selected_audit_subject(value)
    subject_type, subject_id = value.to_s.split(":", 2)
    return unless subject_type.in?(AUTHOR_TYPES) && subject_id.present?

    subject_type.constantize.find_by(id: subject_id)
  end

  def selected_month
    month = Integer(params[:month], exception: false)
    month if month&.between?(1, 12)
  end

  def selected_year
    year = Integer(params[:year], exception: false)
    year if year&.positive?
  end

  def audit_year_options
    min_created_at = AuditAction.minimum(:created_at)
    max_created_at = AuditAction.maximum(:created_at)
    years = [ Time.zone.today.year ]
    years.concat((min_created_at.year..max_created_at.year).to_a) if min_created_at && max_created_at
    years << @selected_year if @selected_year
    years.compact.uniq.sort
  end

  def filter_audit_actions_by_period(audit_actions)
    return audit_actions.where(created_at: month_range(@selected_year, @selected_month)) if @selected_year && @selected_month
    return audit_actions.where(created_at: year_range(@selected_year)) if @selected_year
    return audit_actions unless @selected_month

    condition = @year_options.map { |year| month_range(year, @selected_month) }
      .map { |range| audit_created_at_range_condition(range) }
      .reduce { |combined_condition, range_condition| combined_condition.or(range_condition) }

    condition ? audit_actions.where(condition) : audit_actions
  end

  def month_range(year, month)
    month_date = Time.zone.local(year, month, 1)

    month_date.beginning_of_month..month_date.end_of_month
  end

  def year_range(year)
    year_date = Time.zone.local(year, 1, 1)

    year_date.beginning_of_year..year_date.end_of_year
  end

  def audit_created_at_range_condition(range)
    table = AuditAction.arel_table

    table[:created_at].gteq(range.begin).and(table[:created_at].lteq(range.end))
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
