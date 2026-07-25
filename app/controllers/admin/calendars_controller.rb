class Admin::CalendarsController < Admin::BaseController
  EMPLOYEE_SEARCH_LIMIT = 8

  def index
    @selected_employee = selected_employee
    @year = selected_year
    @calendar_months = @selected_employee ? calendar_months_for(@selected_employee) : []
  end

  def employee_search
    render partial: "employee_results", locals: {
      employees: employee_search_results,
      selected_employee_id: params[:selected_employee_id].presence
    }
  end

  private

  def selected_employee
    Employee.find_by(id: params[:employee_id].presence) if params[:employee_id].present?
  end

  def selected_year
    year = Integer(params[:year].presence || Time.zone.today.year, exception: false)
    return year if year && year.between?(2000, 2100)

    Time.zone.today.year
  end

  def calendar_months_for(employee)
    start_date = Date.new(@year, 1, 1)
    end_date = Date.new(@year, 12, 31)
    swipes_by_date = employee.swipes.kept
      .where(swipe_at: start_date.beginning_of_day..end_date.end_of_day)
      .chronological
      .group_by { |swipe| swipe.swipe_at.to_date }
    corrections_by_date = employee.swipe_corrections.pending
      .where(day: start_date..end_date)
      .order(created_at: :desc)
      .group_by(&:day)

    (1..12).map do |month|
      first_day = Date.new(@year, month, 1)
      days = Array.new(calendar_leading_blank_days(first_day)) + (first_day..first_day.end_of_month).map do |date|
        day_swipes = swipes_by_date.fetch(date, [])
        day_corrections = corrections_by_date.fetch(date, [])

        {
          date: date,
          status: calendar_day_status(date, day_swipes, day_corrections),
          swipes_count: day_swipes.count,
          worked_seconds: Swipe.paired_work_seconds(day_swipes),
          future: date.future?,
          clickable: !date.future?,
          correction: day_corrections.first
        }
      end

      { month: first_day, days: days }
    end
  end

  def calendar_leading_blank_days(first_day)
    first_day.wday.zero? ? 6 : first_day.wday - 1
  end

  def calendar_day_status(date, swipes, corrections)
    return :warning if corrections.any?
    return :danger if date.past? && swipes.count.odd?
    return :"success_#{[ swipes.count, 4 ].min}" if swipes.any?

    :empty
  end

  def employee_search_results
    employees = Employee.order(:last_name, :first_name, :id)
    query = params[:q].to_s.strip
    return employees.limit(EMPLOYEE_SEARCH_LIMIT) if query.blank?

    normalized_query = query.downcase
    compact_query = normalized_query.gsub(/[ .\-()]/, "")
    national_id_query = Employee.normalize_national_id(query).downcase

    employees
      .where(
        <<~SQL.squish,
          LOWER(COALESCE(first_name, '')) LIKE :query
          OR LOWER(COALESCE(last_name, '')) LIKE :query
          OR LOWER(COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')) LIKE :query
          OR LOWER(COALESCE(national_id, '')) LIKE :national_id_query
          OR LOWER(COALESCE(email, '')) LIKE :query
          OR LOWER(COALESCE(phone, '')) LIKE :query
          OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(COALESCE(phone, '')), ' ', ''), '-', ''), '.', ''), '(', ''), ')', '') LIKE :compact_query
        SQL
        query: "%#{ActiveRecord::Base.sanitize_sql_like(normalized_query)}%",
        national_id_query: "%#{ActiveRecord::Base.sanitize_sql_like(national_id_query)}%",
        compact_query: compact_query.present? ? "%#{ActiveRecord::Base.sanitize_sql_like(compact_query)}%" : ""
      )
      .limit(EMPLOYEE_SEARCH_LIMIT)
  end
end
