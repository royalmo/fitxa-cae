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
    name.split.map(&:first).join.first(2).upcase
  end

  def status_text(status)
    t("statuses.#{status}")
  end

  def clocking_kind_text(kind)
    t("clocking_kinds.#{kind}")
  end

  def source_text(source)
    t("sources.#{source}")
  end
end
