class Admin::DashboardController < Admin::BaseController
  def index
    @month = Time.zone.today
    @stats = dashboard_stats
    @recent_swipes = Swipe.kept.includes(employee: :tags).order(swipe_at: :desc, id: :desc).limit(6)
    @pending_corrections = SwipeCorrection.pending.includes(:employee).order(created_at: :asc).limit(6)
  end

  private

  def dashboard_stats
    [
      {
        icon: "users",
        label: t(".stats.present"),
        value: present_employee_count,
        detail: t(".stats.now")
      },
      {
        icon: "hourglass",
        label: t(".stats.pending_corrections"),
        value: SwipeCorrection.pending.count,
        detail: t(".stats.open")
      },
      {
        icon: "clock",
        label: t(".stats.month_hours"),
        value: helpers.duration_text(month_work_seconds),
        detail: l(@month, format: :month_year)
      },
      {
        icon: "user-x",
        label: t(".stats.inactive"),
        value: Employee.inactive.count,
        detail: t(".stats.employees")
      }
    ]
  end

  def month_work_seconds
    Swipe.kept
      .where(swipe_at: @month.beginning_of_month.beginning_of_day..@month.end_of_month.end_of_day)
      .chronological
      .group_by { |swipe| [ swipe.employee_id, swipe.swipe_at.to_date ] }
      .values
      .sum { |swipes| Swipe.paired_work_seconds(swipes) }
  end

  def present_employee_count
    employee_ids = Employee.active.ids

    Swipe.kept
      .where(employee_id: employee_ids, swipe_at: ..Time.current)
      .order(swipe_at: :desc, id: :desc)
      .group_by(&:employee_id)
      .values
      .map(&:first)
      .count(&:entry?)
  end
end
