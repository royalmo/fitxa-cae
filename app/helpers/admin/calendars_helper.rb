module Admin::CalendarsHelper
  include Admin::SwipesHelper

  def admin_calendar_day_class(day)
    status = day[:status].to_s
    class_names(
      "admin-calendar-day",
      "is-#{status.dasherize}",
      "is-future": day[:future],
      "has-activity": day[:swipes_count].to_i.positive? || day[:correction].present?
    )
  end

  def admin_calendar_day_title(day)
    parts = [ l(day[:date], format: :long) ]
    parts << t("admin.calendars.index.swipes_count", count: day[:swipes_count]) if day[:swipes_count].to_i.positive?
    parts << status_text(:pending) if day[:correction].present?
    parts.join(" · ")
  end

  def admin_calendar_day_popover_title(day)
    l(day[:date], format: :long)
  end

  def admin_calendar_day_popover_content(employee, day)
    safe_join([
      tag.p(admin_calendar_day_explanation(day), class: "small text-body-secondary mb-2"),
      link_to(
        admin_correction_day_path(employee, day[:date], day[:correction]),
        class: "btn btn-sm btn-outline-secondary d-inline-flex align-items-center gap-1 admin-calendar-popover-action"
      ) do
        safe_join([
          icon(admin_calendar_day_action_icon(day)),
          tag.span(admin_calendar_day_action_label(day))
        ])
      end
    ])
  end

  def admin_calendar_day_action_icon(day)
    return "eye" if day[:correction].present?
    return "plus" if day[:swipes_count].to_i.zero?

    "pencil"
  end

  def admin_calendar_day_action_label(day)
    return t("admin.calendars.index.review") if day[:correction].present?
    return t("admin.calendars.index.create_swipes") if day[:swipes_count].to_i.zero?

    t("admin.calendars.index.correct")
  end

  def admin_calendar_day_explanation(day)
    if day[:correction].present?
      return t("admin.calendars.index.day_reasons.pending_correction")
    end

    case day[:status]
    when :danger
      t("admin.calendars.index.day_reasons.odd_swipes", count: day[:swipes_count])
    when :empty
      t("admin.calendars.index.day_reasons.empty")
    else
      t(
        "admin.calendars.index.day_reasons.swipes",
        count: day[:swipes_count],
        duration: duration_text(day[:worked_seconds])
      )
    end
  end
end
