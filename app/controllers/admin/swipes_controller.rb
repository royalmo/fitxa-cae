class Admin::SwipesController < Admin::BaseController
  include EmployeeClockingSummaries

  SWIPES_START_YEAR = 2026

  def index
    @selected_employee = selected_employee
    @month = selected_month
    @year_options = year_options
    @start_date = @month.beginning_of_month
    @end_date = @month.end_of_month
    @clocking_days = @selected_employee ? clocking_days_for(@selected_employee) : []
  end

  private

  def selected_employee
    Employee.find_by(id: params[:employee_id].presence) if params[:employee_id].present?
  end

  def selected_month
    legacy_month = legacy_selected_month
    return legacy_month if legacy_month

    Date.new(selected_year, selected_month_number, 1)
  rescue Date::Error
    Time.zone.today.beginning_of_month
  end

  def legacy_selected_month
    month_param = params[:month].to_s
    return unless month_param.match?(/\A\d{4}-\d{2}\z/)

    parsed_month = Date.strptime(month_param, "%Y-%m")
    return parsed_month if selectable_year?(parsed_month.year) && parsed_month.year <= Time.zone.today.year

    nil
  rescue Date::Error
    nil
  end

  def selected_month_number
    month = Integer(params[:month].presence || Time.zone.today.month, exception: false)
    return month if month&.between?(1, 12)

    Time.zone.today.month
  end

  def selected_year
    year = Integer(params[:year].presence || Time.zone.today.year, exception: false)
    return year if selectable_year?(year) && year <= Time.zone.today.year

    Time.zone.today.year
  end

  def year_options
    previous_year = @month.year if @month.year < SWIPES_START_YEAR
    ([ previous_year ].compact + (SWIPES_START_YEAR..Time.zone.today.year).to_a).uniq
  end

  def selectable_year?(year)
    year&.between?(2000, 2100)
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
        day_swipes: day_swipes,
        swipes_count: effective_swipes.count,
        worked_seconds: Swipe.paired_work_seconds(effective_swipes),
        correction: day_corrections.find(&:pending?),
        corrections: day_corrections
      }
    end
  end
end
