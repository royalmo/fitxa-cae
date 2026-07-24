module Employee::DashboardHelper
  def dashboard_date_text(date)
    l(date, format: :weekday_day_month_year).downcase.sub(/\A./) { |char| char.upcase }
  end

  def dashboard_duration_text(total_seconds)
    minutes = [ total_seconds.to_i / 60, 0 ].max
    hours, remaining_minutes = minutes.divmod(60)

    "#{hours} h #{remaining_minutes.to_s.rjust(2, "0")} min"
  end

  def dashboard_duration_parts(total_seconds)
    total_seconds = [ total_seconds.to_i, 0 ].max
    hours, remaining_seconds = total_seconds.divmod(1.hour)
    minutes, seconds = remaining_seconds.divmod(1.minute)

    {
      hours: hours,
      minutes: minutes.to_s.rjust(2, "0"),
      seconds: seconds.to_s.rjust(2, "0")
    }
  end

  def weekly_activity_text(week_summary)
    t(
      "employee.dashboard.show.week_activity",
      days: t("employee.dashboard.show.week_days", count: week_summary[:days]),
      duration: dashboard_duration_text(week_summary[:worked_seconds])
    )
  end

  def weekly_corrections_text(week_summary)
    return t("employee.dashboard.show.week_corrections_empty") if weekly_corrections_empty?(week_summary)

    weekly_correction_parts(week_summary).map { |part| part[:text] }.join(", ")
  end

  def weekly_correction_parts(week_summary)
    counts = week_summary.fetch(:correction_counts, {}).transform_keys(&:to_s)

    SwipeCorrection.filterable_statuses.filter_map do |status|
      count = counts.fetch(status, 0)
      next if count.zero?

      {
        status: status,
        text: "#{count} #{weekly_correction_status_text(status, count)}"
      }
    end
  end

  def weekly_corrections_empty?(week_summary)
    week_summary.fetch(:correction_counts, {}).values.sum.zero?
  end

  def dashboard_clockings_path(date)
    clockings_path(month: date.month, year: date.year)
  end

  def dashboard_corrections_path(date, status: nil)
    corrections_path({ month: date.month, year: date.year, status: status }.compact)
  end

  private

  def weekly_correction_status_text(status, count)
    if count == 1
      t("employee.corrections.statuses.#{status}").downcase
    else
      t("employee.corrections.index.empty_statuses.#{status}")
    end
  end
end
