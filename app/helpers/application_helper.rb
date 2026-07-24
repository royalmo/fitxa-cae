require "cgi"

module ApplicationHelper
  EMPLOYEE_THEME_STORAGE_KEY = "fitxa-cae.employee.theme"
  EMPLOYEE_LIGHT_THEME_COLOR = "#e30613"
  EMPLOYEE_DARK_THEME_COLOR = "#121214"

  def nav_item_class(path, exact: nil)
    target = path.to_s
    exact = target == "/" if exact.nil?
    active = exact ? request.path == target : request.path == target || request.path.start_with?("#{target}/")

    class_names("nav-item", "is-active": active)
  end

  def badge_class(status)
    class_names("badge", "badge-#{status}")
  end

  def status_text(status)
    t("statuses.#{status}")
  end

  def browser_title(title = nil, admin: false)
    suffix = admin ? "FitxaCAE Admin" : "FitxaCAE"

    [ decoded_title(title).presence, suffix ].compact.join(" | ")
  end

  def app_version
    Rails.configuration.x.app_version
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

  def employee_theme_preference(employee)
    employee&.theme_preference || Employee::DEFAULT_THEME_PREFERENCE
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
      attributes[:title] = title
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

  def clocking_swipe_rows(swipes)
    rows = []
    current_row = nil

    swipes.each do |swipe|
      if swipe.entry?
        current_row = { entry: swipe, exit: nil }
        rows << current_row
      elsif current_row && current_row[:exit].blank?
        current_row[:exit] = swipe
      else
        current_row = { entry: nil, exit: swipe }
        rows << current_row
      end
    end

    rows
  end

  def clocking_swipe_class(swipe)
    class_names(
      "clocking-swipe",
      "is-pending-requested": clocking_swipe_pending_requested?(swipe),
      "is-pending-invalidated": clocking_swipe_pending_invalidated?(swipe)
    )
  end

  def clocking_swipe_pending_requested?(swipe)
    swipe.respond_to?(:pending_requested?) && swipe.pending_requested?
  end

  def clocking_swipe_pending_invalidated?(swipe)
    swipe.respond_to?(:pending_invalidated?) && swipe.pending_invalidated?
  end

  private

  def decoded_title(title)
    CGI.unescapeHTML(title.to_s)
  end
end
