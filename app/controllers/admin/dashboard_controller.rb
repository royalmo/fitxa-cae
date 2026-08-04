class Admin::DashboardController < Admin::BaseController
  STATISTIC_METRICS = %w[active_user_count pending_correction_count].freeze
  STATISTIC_PERIODS = %w[60d 1y total].freeze

  def index
    @today = Time.zone.today
    @stats = dashboard_stats
    @active_people_chart_data = statistics_chart_data("active_user_count", "60d")
    @recent_audit_actions = AuditAction.includes(:author).order(created_at: :desc, id: :desc).limit(10)
  end

  def statistics
    render json: statistics_chart_data(statistic_metric, statistic_period)
  end

  private

  def dashboard_stats
    [
      {
        icon: "users",
        label: t(".stats.present"),
        value: "#{working_employee_count}/#{active_employee_count}",
        path: admin_employees_path
      },
      {
        icon: "hourglass",
        label: t(".stats.pending_corrections"),
        value: SwipeCorrection.pending.count,
        path: admin_corrections_path(status: "pending")
      },
      {
        icon: "clock",
        label: t(".stats.month_hours"),
        value: helpers.duration_hours_text(month_work_seconds),
        path: admin_swipes_path(month: @today.month, year: @today.year)
      },
      {
        icon: "calendar-days",
        label: t(".stats.year_hours"),
        value: helpers.duration_hours_text(year_work_seconds),
        path: admin_calendars_path(year: @today.year)
      }
    ]
  end

  def month_work_seconds
    Swipe.kept
      .where(swipe_at: @today.beginning_of_month.beginning_of_day..@today.end_of_day)
      .chronological
      .group_by { |swipe| [ swipe.employee_id, swipe.swipe_at.to_date ] }
      .values
      .sum { |swipes| Swipe.paired_work_seconds(swipes) }
  end

  def year_work_seconds
    Swipe.kept
      .where(swipe_at: @today.beginning_of_year.beginning_of_day..@today.end_of_day)
      .chronological
      .group_by { |swipe| [ swipe.employee_id, swipe.swipe_at.to_date ] }
      .values
      .sum { |swipes| Swipe.paired_work_seconds(swipes) }
  end

  def working_employee_count
    Swipe.kept
      .joins(:employee)
      .merge(Employee.active)
      .where(swipe_at: @today.beginning_of_day..Time.current)
      .order(swipe_at: :desc, id: :desc)
      .group_by(&:employee_id)
      .values
      .map(&:first)
      .count(&:entry?)
  end

  def active_employee_count
    Employee.active.count
  end

  def statistic_metric
    params[:metric].presence_in(STATISTIC_METRICS) || "active_user_count"
  end

  def statistic_period
    params[:period].presence_in(STATISTIC_PERIODS) || "60d"
  end

  def statistics_chart_data(metric, period)
    records = statistics_records(period).select(:snapshot_at, metric)

    {
      metric: metric,
      period: period,
      label: t("admin.dashboard.index.statistics.metrics.#{metric}"),
      color: statistic_metric_color(metric),
      labels: records.map { |daily_statistic| l(daily_statistic.snapshot_at, format: :short) },
      values: records.map { |daily_statistic| daily_statistic.public_send(metric) }
    }
  end

  def statistics_records(period)
    records = DailyStatistic.chronological

    case period
    when "60d"
      records.where(snapshot_at: 59.days.ago.to_date..)
    when "1y"
      records.where(snapshot_at: 1.year.ago.to_date..)
    else
      records
    end
  end

  def statistic_metric_color(metric)
    {
      "active_user_count" => "#198754",
      "pending_correction_count" => "#f59f00"
    }.fetch(metric)
  end
end
