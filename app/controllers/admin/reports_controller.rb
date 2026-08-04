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
end
