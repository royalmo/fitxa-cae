class Admin::ReportsController < Admin::BaseController
  def index
    @month = report_month
    @employees = Employee.order(:last_name, :first_name, :id)
    @selected_employee_id = params[:employee_id].presence
    @report_employees = report_employees.to_a
    @swipes_by_employee_id = report_swipes_by_employee_id
    @correction_counts_by_employee_id = report_correction_counts_by_employee_id
    @report_rows = @report_employees.map { |employee| report_row_for(employee) }
  end

  private

  def report_month
    Date.strptime(params[:month].presence || Time.zone.today.strftime("%Y-%m"), "%Y-%m")
  rescue Date::Error
    Time.zone.today.beginning_of_month
  end

  def report_range
    @report_range ||= @month.beginning_of_month..@month.end_of_month
  end

  def report_time_range
    @report_time_range ||= report_range.begin.beginning_of_day..report_range.end.end_of_day
  end

  def report_employees
    employees = @employees
    employees = employees.where(id: @selected_employee_id) if @selected_employee_id.present?
    employees
  end

  def report_row_for(employee)
    swipes = @swipes_by_employee_id.fetch(employee.id, [])

    {
      employee: employee,
      worked_seconds: swipes.group_by { |swipe| swipe.swipe_at.to_date }.values.sum { |day_swipes| Swipe.paired_work_seconds(day_swipes) },
      days: swipes.map { |swipe| swipe.swipe_at.to_date }.uniq.count,
      corrections: @correction_counts_by_employee_id.fetch(employee.id, 0)
    }
  end

  def report_employee_ids
    @report_employees.map(&:id)
  end

  def report_swipes_by_employee_id
    Swipe.kept
      .where(employee_id: report_employee_ids, swipe_at: report_time_range)
      .chronological
      .group_by(&:employee_id)
  end

  def report_correction_counts_by_employee_id
    SwipeCorrection
      .where(employee_id: report_employee_ids, day: report_range)
      .group(:employee_id)
      .count
  end
end
