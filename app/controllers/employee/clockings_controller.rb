class Employee::ClockingsController < ApplicationController
  include EmployeeClockingSummaries

  layout "employee"

  def index
    @employee = current_employee
    @min_clocking_month = @employee.created_at.to_date.beginning_of_month
    @max_clocking_month = Time.zone.today.beginning_of_month
    @month = requested_clocking_month || @max_clocking_month
    @clocking_month_reachable = clocking_month_reachable?(@month)
    @previous_month, @next_month = clocking_month_navigation
    @clocking_days = if @clocking_month_reachable
      clocking_day_summaries(
        @employee,
        start_date: @month,
        end_date: [ @month.end_of_month, Time.zone.today ].min
      )
    else
      []
    end
  end

  def clock_in
    if current_employee.clocked_in?
      redirect_to root_path, alert: t("employee.flash.already_clocked_in")
      return
    end

    current_employee.swipes.create!(
      swipe_at: Time.current,
      kind: :entry,
      metadata: "employee_portal"
    )

    redirect_to root_path, notice: t("employee.flash.clocked_in")
  end

  def clock_out
    unless current_employee.clocked_in?
      redirect_to root_path, alert: t("employee.flash.already_clocked_out")
      return
    end

    current_employee.swipes.create!(
      swipe_at: Time.current,
      kind: :exit,
      metadata: "employee_portal"
    )

    redirect_to root_path, notice: t("employee.flash.clocked_out")
  end

  private

  def clocking_month_reachable?(month)
    month.between?(@min_clocking_month, @max_clocking_month)
  end

  def clocking_month_navigation
    if @month < @min_clocking_month
      [ nil, @min_clocking_month ]
    elsif @month > @max_clocking_month
      [ @max_clocking_month, nil ]
    else
      [
        (@month.prev_month if @month > @min_clocking_month),
        (@month.next_month if @month < @max_clocking_month)
      ]
    end
  end

  def requested_clocking_month
    return if params[:month].blank? && params[:year].blank?

    year = requested_clocking_year
    month = requested_clocking_month_number(year)

    return unless month&.between?(1, 12) && year&.positive?

    Date.new(year, month, 1)
  rescue Date::Error
    nil
  end

  def requested_clocking_year
    requested_year = Integer(params[:year], exception: false)
    return requested_year if requested_year

    @min_clocking_month.year if @min_clocking_month.year == @max_clocking_month.year
  end

  def requested_clocking_month_number(year)
    requested_month = Integer(params[:month], exception: false)
    return requested_month if requested_month
    return unless year

    if year <= @min_clocking_month.year
      @min_clocking_month.month
    elsif year >= @max_clocking_month.year
      @max_clocking_month.month
    else
      1
    end
  end
end
