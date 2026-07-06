module ApplicationHelper
  def nav_item_class(path, exact: nil)
    target = path.to_s
    exact = target == "/" if exact.nil?
    active = exact ? request.path == target : request.path == target || request.path.start_with?("#{target}/")

    class_names("nav-item", "is-active": active)
  end

  def badge_class(status)
    class_names("badge", "badge-#{status}")
  end

  def initials(name)
    name.to_s.split.map(&:first).join.first(2).to_s.upcase.presence || "?"
  end

  def status_text(status)
    t("statuses.#{status}")
  end

  def clocking_kind_text(kind)
    t("clocking_kinds.#{kind}", default: kind.to_s.humanize)
  end

  def source_text(source)
    t("sources.#{source}", default: source.to_s.humanize)
  end

  def employee_display_name(employee)
    employee&.full_name.presence || employee&.first_name.presence || t("employee.guest")
  end

  def manager_display_name(manager)
    manager&.full_name.presence || manager&.email.presence || t("admin.guest")
  end

  def duration_text(total_seconds)
    minutes = [ total_seconds.to_i / 60, 0 ].max
    hours, remaining_minutes = minutes.divmod(60)

    "#{hours} h #{remaining_minutes.to_s.rjust(2, "0")} min"
  end

  def icon(name, options = {})
    title = options.delete(:title).presence
    attributes = options.merge(class: class_names("icon", options[:class]), focusable: "false")

    if title
      attributes[:role] = "img"
      attributes[:"aria-label"] = title
    else
      attributes[:"aria-hidden"] = "true"
    end

    lucide_icon(name, **attributes)
  end

  def clocking_icon_name(kind)
    {
      entry: "log-in",
      exit: "log-out",
      in: "log-in",
      out: "log-out",
      pause_start: "pause",
      pause_end: "play"
    }.fetch(kind.to_sym, "clock")
  end
end
