class Admin::SwipesController < Admin::BaseController
  include EmployeeClockingSummaries

  SWIPES_START_YEAR = 2026
  SEARCH_MODES = %w[person category].freeze
  CATEGORY_FILTERS = %w[erroneous_swipes pending_corrections].freeze
  CATEGORY_DAYS_PER_PAGE = 20

  def index
    @search_mode = selected_search_mode
    @month = selected_month
    @year_options = year_options
    @start_date = @month.beginning_of_month
    @end_date = @month.end_of_month
    @selected_employee = @search_mode == "person" ? selected_employee : nil
    @selected_category = @search_mode == "category" ? selected_category : nil
    @clocking_days = @selected_employee ? clocking_days_for(@selected_employee) : []
    @category_clocking_days = @selected_category ? category_clocking_days : []
  end

  private

  def selected_search_mode
    params[:search_mode].presence_in(SEARCH_MODES) || "person"
  end

  def selected_employee
    Employee.find_by(id: params[:employee_id].presence) if params[:employee_id].present?
  end

  def selected_category
    params[:category].presence_in(CATEGORY_FILTERS)
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
      clocking_day(employee: employee, date: date, day_swipes: swipes_by_date.fetch(date, []), day_corrections: corrections_by_date.fetch(date, []))
    end
  end

  def category_clocking_days
    keys = category_clocking_day_keys
    return paginate_category_clocking_day_keys([]) if keys.empty?

    employee_ids = keys.map(&:first).uniq
    employees_by_id = Employee.where(id: employee_ids).index_by(&:id)
    keys = keys.sort_by { |employee_id, date| category_clocking_day_sort_key(employees_by_id.fetch(employee_id), date) }
    keys = paginate_category_clocking_day_keys(keys)
    return [] if keys.empty?

    employee_ids = keys.map(&:first).uniq
    swipes_by_key = Swipe.kept
      .where(employee_id: employee_ids, swipe_at: @start_date.beginning_of_day..@end_date.end_of_day)
      .chronological
      .to_a
      .group_by { |swipe| [ swipe.employee_id, swipe.swipe_at.in_time_zone.to_date ] }
    corrections_by_key = SwipeCorrection
      .where(employee_id: employee_ids, day: @start_date..@end_date)
      .order(created_at: :desc)
      .to_a
      .group_by { |correction| [ correction.employee_id, correction.day ] }

    keys.map do |employee_id, date|
      clocking_day(
        employee: employees_by_id.fetch(employee_id),
        date: date,
        day_swipes: swipes_by_key.fetch([ employee_id, date ], []),
        day_corrections: corrections_by_key.fetch([ employee_id, date ], [])
      )
    end
  end

  def category_clocking_day_keys
    case @selected_category
    when "erroneous_swipes"
      erroneous_swipe_day_keys
    when "pending_corrections"
      pending_correction_day_keys
    else
      []
    end
  end

  def erroneous_swipe_day_keys
    Swipe.kept
      .where(swipe_at: @start_date.beginning_of_day..@end_date.end_of_day)
      .chronological
      .to_a
      .group_by { |swipe| [ swipe.employee_id, swipe.swipe_at.in_time_zone.to_date ] }
      .filter_map do |(employee_id, date), swipes|
        next unless date.past?
        next unless swipes.size.odd?

        [ employee_id, date ]
      end
  end

  def pending_correction_day_keys
    SwipeCorrection.pending
      .where(day: @start_date..@end_date)
      .distinct
      .pluck(:employee_id, :day)
  end

  def clocking_day(employee:, date:, day_swipes:, day_corrections:)
    display_swipes = clocking_display_swipes(day_swipes, day_corrections)
    effective_swipes = effective_clocking_display_swipes(display_swipes)

    {
      employee: employee,
      date: date,
      swipes: display_swipes,
      day_swipes: day_swipes,
      swipes_count: effective_swipes.count,
      worked_seconds: Swipe.paired_work_seconds(effective_swipes),
      correction: day_corrections.find(&:pending?),
      corrections: day_corrections
    }
  end

  def category_clocking_day_sort_key(employee, date)
    [ date, employee.last_name.to_s.downcase, employee.first_name.downcase, employee.id ]
  end

  def paginate_category_clocking_day_keys(keys)
    @admin_records_count = keys.size
    @admin_total_pages = [ (@admin_records_count.to_f / CATEGORY_DAYS_PER_PAGE).ceil, 1 ].max
    @admin_page = [ requested_admin_page, @admin_total_pages ].min
    @admin_previous_page = @admin_page - 1 if @admin_page > 1
    @admin_next_page = @admin_page + 1 if @admin_page < @admin_total_pages
    @admin_records_range_start = ((@admin_page - 1) * CATEGORY_DAYS_PER_PAGE) + 1 if @admin_records_count.positive?
    page_keys = keys.slice((@admin_page - 1) * CATEGORY_DAYS_PER_PAGE, CATEGORY_DAYS_PER_PAGE) || []
    @admin_records_range_end = @admin_records_range_start + page_keys.size - 1 if @admin_records_range_start
    page_keys
  end
end
