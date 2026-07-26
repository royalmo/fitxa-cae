module Admin::CorrectionsHelper
  include Employee::CorrectionsHelper

  def admin_corrections_month_options
    I18n.t("date.month_names").each_with_index.filter_map do |month_name, month_number|
      [ month_name, month_number ] if month_number.positive?
    end
  end

  def admin_corrections_status_filter_label(status)
    t("admin.corrections.index.status_filters.#{status.presence || "all"}")
  end

  def admin_corrections_status_filter_icon(status)
    status.present? ? correction_status_icon_name(status) : "list-filter"
  end
end
