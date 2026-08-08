class Admin::AuditActionsController < Admin::BaseController
  AUDIT_ACTIONS_PER_PAGE = 30
  AUDIT_ACTIONS_EXPORT_LIMIT = 10_000
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
      .limit(selected_export_limit)
      .to_a
    csv = audit_actions_csv(audit_actions)

    record_audit_action!(
      author: current_manager,
      recipient: current_manager,
      kind: "audit_actions.exported",
      extra_info: audit_actions_export_audit_details(audit_actions)
    )

    send_data csv,
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
        "datetime",
        "author",
        "recipient",
        "kind",
        "pretty_activity",
        "details"
      ]

      audit_actions.each do |audit_action|
        csv << [
          audit_action.created_at.iso8601,
          audit_subject_identifier(audit_action.author),
          audit_subject_identifier(audit_action.recipient),
          audit_action.kind,
          helpers.admin_audit_action_detail_text(audit_action),
          audit_action_details_json(audit_action)
        ]
      end
    end
  end

  def selected_export_limit
    limit = Integer(params[:limit], exception: false)
    return [ 100, AUDIT_ACTIONS_EXPORT_LIMIT ].min unless limit

    limit.clamp(0, AUDIT_ACTIONS_EXPORT_LIMIT)
  end

  def audit_subject_identifier(record)
    case record
    when Employee
      "employee:#{record.id}"
    when Manager
      "manager:#{record.id}"
    else
      record.to_s.downcase
    end
  end

  def audit_action_details_json(audit_action)
    JSON.generate(audit_action.extra_info.presence || {})
  rescue JSON::GeneratorError
    audit_action.extra_info.to_s
  end

  def audit_actions_export_audit_details(audit_actions)
    {
      exported_count: audit_actions.size,
      limit: selected_export_limit,
      filters: {
        author_type: @selected_author_type,
        author: audit_subject_identifier(@selected_author),
        recipient: audit_subject_identifier(@selected_recipient),
        kind: @selected_kind,
        month: @selected_month,
        year: @selected_year
      }.compact_blank
    }
  end
end
