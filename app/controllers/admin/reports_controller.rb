class Admin::ReportsController < Admin::BaseController
  REPORT_START_YEAR = 2026
  REPORT_SCOPES = %w[person tag company].freeze

  def index
    @selected_month = selected_month || Time.zone.today.month
    @selected_year = selected_year || Time.zone.today.year
    @selected_period = Date.new(@selected_year, @selected_month, 1)
    @year_options = report_year_options
    @selected_report_scope = selected_report_scope
    @selected_employee = selected_employee
    @selected_tag = selected_tag
    @period_problem = period_problem_for(@selected_period)
  end

  def period_problems
    period_start = Date.new(selected_year || Time.zone.today.year, selected_month || Time.zone.today.month, 1)
    period_problem = period_problem_for(period_start)

    render json: {
      html: render_to_string(
        partial: "admin/reports/period_problem",
        formats: [ :html ],
        locals: { period_problem: period_problem }
      )
    }
  end

  def monthly_summary
    period_start = Date.new(selected_year || Time.zone.today.year, selected_month || Time.zone.today.month, 1)
    report = Reports::MonthlySummaryReport.new(month: period_start.month, year: period_start.year).to_h
    csv = Reports::MonthlySummaryCsv.new(report: report).to_csv

    record_audit_action!(
      author: current_manager,
      recipient: current_manager,
      kind: "report.monthly_summary_csv_downloaded",
      extra_info: audit_period_details(month: period_start.month, year: period_start.year).merge(
        report_kind: "monthly_summary",
        format: "csv"
      )
    )

    send_data csv,
      filename: Reports::Filenames.monthly_summary_csv(period_start),
      type: "text/csv; charset=utf-8",
      disposition: :attachment
  end

  private

  def selected_month
    month = Integer(params[:month], exception: false)
    month if month&.between?(1, 12)
  end

  def selected_year
    year = Integer(params[:year], exception: false)
    year if year&.positive?
  end

  def selected_report_scope
    params[:report_scope].presence_in(REPORT_SCOPES) || inferred_report_scope || "person"
  end

  def inferred_report_scope
    return "person" if params[:employee_id].present?
    return "tag" if params[:tag_id].present?

    nil
  end

  def report_year_options
    years = (REPORT_START_YEAR..Time.zone.today.year).to_a
    years << @selected_year if @selected_year

    years.compact.uniq.sort
  end

  def selected_employee
    Employee.find_by(id: params[:employee_id]) if params[:employee_id].present?
  end

  def selected_tag
    Tag.active.find_by(id: params[:tag_id]) if params[:tag_id].present?
  end

  def period_problem_for(period_start)
    if erroneous_swipes_in_period?(period_start)
      {
        kind: "erroneous_swipes",
        message: t("admin.reports.index.period_problems.erroneous_swipes"),
        path: admin_swipes_path(
          search_mode: "category",
          category: "erroneous_swipes",
          month: period_start.month,
          year: period_start.year
        )
      }
    elsif pending_corrections_in_period?(period_start)
      {
        kind: "pending_corrections",
        message: t("admin.reports.index.period_problems.pending_corrections"),
        path: admin_corrections_path(
          status: "pending",
          month: period_start.month,
          year: period_start.year
        )
      }
    end
  end

  def erroneous_swipes_in_period?(period_start)
    swipes = Swipe.kept
      .where(swipe_at: period_start.beginning_of_day..period_start.end_of_month.end_of_day)
      .pluck(:employee_id, :swipe_at)

    swipes
      .group_by { |employee_id, swipe_at| [ employee_id, swipe_at.in_time_zone.to_date ] }
      .any? { |(_employee_id, date), day_swipes| date.past? && day_swipes.size.odd? }
  end

  def pending_corrections_in_period?(period_start)
    SwipeCorrection.pending
      .where(day: period_start..period_start.end_of_month)
      .exists?
  end
end
