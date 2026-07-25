class Admin::SwipesController < Admin::BaseController
  include EmployeeClockingSummaries

  def index
    @employees = Employee.order(:last_name, :first_name, :id)
    @selected_employee = selected_employee
    @month = selected_month
    @start_date = @month.beginning_of_month
    @end_date = @month.end_of_month
    @clocking_days = @selected_employee ? clocking_days_for(@selected_employee) : []
  end

  private

  def selected_employee
    @employees.find_by(id: params[:employee_id].presence) || @employees.first
  end

  def selected_month
    Date.strptime(params[:month].presence || Time.zone.today.strftime("%Y-%m"), "%Y-%m")
  rescue Date::Error
    Time.zone.today.beginning_of_month
  end

  def clocking_days_for(employee)
    swipes = employee.swipes.kept.where(swipe_at: @start_date.beginning_of_day..@end_date.end_of_day).chronological.to_a
    corrections = employee.swipe_corrections.where(day: @start_date..@end_date).order(created_at: :desc).to_a
    swipes_by_date = swipes.group_by { |swipe| swipe.swipe_at.to_date }
    corrections_by_date = corrections.group_by(&:day)

    (@start_date..@end_date).map do |date|
      day_swipes = swipes_by_date.fetch(date, [])
      day_corrections = corrections_by_date.fetch(date, [])
      display_swipes = clocking_display_swipes(day_swipes, day_corrections)
      effective_swipes = effective_clocking_display_swipes(display_swipes)

      {
        date: date,
        swipes: display_swipes,
        swipes_count: effective_swipes.count,
        worked_seconds: Swipe.paired_work_seconds(effective_swipes),
        status: admin_clocking_day_status(day_swipes, day_corrections, effective_swipes),
        correction: day_corrections.find(&:pending?)
      }
    end
  end

  def admin_clocking_day_status(day_swipes, day_corrections, effective_swipes)
    return :odd if effective_swipes.count.odd?

    clocking_day_status(day_swipes, day_corrections)
  end
end
