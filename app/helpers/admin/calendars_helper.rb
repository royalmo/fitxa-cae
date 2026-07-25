module Admin::CalendarsHelper
  include Admin::SwipesHelper

  def admin_calendar_day_class(day)
    status = day[:status].to_s
    class_names(
      "admin-calendar-day",
      "is-#{status.dasherize}",
      "has-activity": day[:swipes_count].to_i.positive? || day[:correction].present?
    )
  end

  def admin_calendar_day_title(day)
    parts = [ l(day[:date], format: :long) ]
    parts << t("admin.calendars.index.swipes_count", count: day[:swipes_count]) if day[:swipes_count].to_i.positive?
    parts << status_text(:pending) if day[:correction].present?
    parts.join(" · ")
  end
end
