require "cgi"

module ApplicationHelper
  EMPLOYEE_THEME_STORAGE_KEY = "fitxa-cae.employee.theme"
  EMPLOYEE_LIGHT_THEME_COLOR = "#e30613"
  EMPLOYEE_DARK_THEME_COLOR = "#121214"

  def app_name
    Rails.configuration.x.app_name
  end

  def app_admin_name
    "#{app_name} Admin"
  end

  def app_slug
    Rails.configuration.x.app_slug
  end

  def app_short_name
    app_name
  end

  def legal_notice_url
    Rails.configuration.x.legal_notice_url
  end

  def link_button_href
    Rails.configuration.x.link_button_href
  end

  def link_button_text
    Rails.configuration.x.link_button_text
  end

  def link_button_enabled?
    link_button_href.present? && link_button_text.present?
  end

  def app_brand_prefix
    app_name.start_with?("Fitxa") ? "Fitxa" : app_name
  end

  def app_brand_suffix
    return unless app_name.start_with?("Fitxa")

    app_name.delete_prefix("Fitxa").presence
  end

  def app_brand_suffix_image_asset
    Rails.configuration.x.app_brand_suffix_image
  end

  def app_brand_suffix_image_path
    configured_image_path(app_brand_suffix_image_asset)
  end

  def app_icon_png_path
    configured_image_path(Rails.configuration.x.app_icon_png, fallback: "/icon.png")
  end

  def app_icon_svg_path
    configured_image_path(Rails.configuration.x.app_icon_svg, fallback: "/icon.svg")
  end

  def app_favicon_path
    configured_image_path(Rails.configuration.x.app_favicon, fallback: "/favicon.ico")
  end

  def pwa_icon_png_path
    configured_image_path(Rails.configuration.x.app_pwa_icon_png, fallback: "/pwa-icon-512.png")
  end

  def pwa_icon_192_png_path
    configured_image_path(Rails.configuration.x.app_pwa_icon_192_png, fallback: "/pwa-icon-192.png")
  end

  def nav_item_class(path, exact: nil)
    target = path.to_s
    exact = target == "/" if exact.nil?
    active = exact ? request.path == target : request.path == target || request.path.start_with?("#{target}/")

    class_names("nav-item", "is-active": active)
  end

  def badge_class(status)
    class_names("badge", "badge-#{status}")
  end

  def bootstrap_status_badge_class(status)
    class_names("badge rounded-pill d-inline-flex align-items-center gap-1", bootstrap_status_badge_variant(status))
  end

  def status_text(status)
    t("statuses.#{status}")
  end

  def browser_title(title = nil, admin: false)
    suffix = admin ? app_admin_name : app_name

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

  def duration_hours_text(total_seconds)
    hours = [ total_seconds.to_i / 3600, 0 ].max

    "#{hours} h"
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

  def bootstrap_status_badge_variant(status)
    case status.to_s
    when "active", "approved", "complete", "corrected"
      "text-bg-success"
    when "pending", "open"
      "text-bg-warning"
    when "rejected", "odd"
      "text-bg-danger"
    else
      "text-bg-secondary"
    end
  end

  def configured_image_path(asset, fallback: nil)
    return fallback if asset.blank?

    asset = asset.to_s
    return asset if asset.start_with?("/", "http://", "https://", "//")

    image_path(asset)
  end
end
