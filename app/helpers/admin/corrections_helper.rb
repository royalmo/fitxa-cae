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

  def admin_correction_status_text(status)
    correction_status_text(status)
  end

  def admin_correction_actor_name(actor)
    case actor
    when Manager
      manager_display_name(actor)
    when Employee
      employee_display_name(actor)
    else
      "---"
    end
  end

  def admin_correction_review_modal_id(correction, action)
    "admin_correction_#{action}_modal_#{correction.id}"
  end

  def admin_correction_review_path(correction, action)
    action.to_sym == :approve ? approve_admin_correction_path(correction) : reject_admin_correction_path(correction)
  end

  def admin_correction_review_button_class(action)
    class_names(
      "btn btn-sm admin-row-action",
      action.to_sym == :approve ? "btn-outline-success" : "btn-outline-danger"
    )
  end

  def admin_correction_review_submit_class(action)
    class_names("btn", action.to_sym == :approve ? "btn-success" : "btn-danger")
  end

  def admin_correction_created_ago_text(correction, capitalize: false)
    admin_correction_relative_time_text(correction.created_at, capitalize: capitalize)
  end

  def admin_correction_relative_time_text(time, capitalize: false)
    seconds = [ (Time.current - time).to_i, 0 ].max

    text = case seconds
    when 0...60
      t("admin.corrections.index.review.created_ago.less_than_minute")
    when 60...1.hour
      t("admin.corrections.index.review.created_ago.minute", count: rounded_time_count(seconds, 1.minute))
    when 1.hour...1.day
      t("admin.corrections.index.review.created_ago.hour", count: rounded_time_count(seconds, 1.hour))
    when 1.day...60.days
      t("admin.corrections.index.review.created_ago.day", count: rounded_time_count(seconds, 1.day))
    when 60.days...2.years
      t("admin.corrections.index.review.created_ago.month", count: rounded_time_count(seconds, 30.days))
    else
      t("admin.corrections.index.review.created_ago.year", count: rounded_time_count(seconds, 1.year))
    end

    capitalize ? text.sub(/\A./) { |character| character.upcase } : text
  end

  def admin_correction_change_items(correction, day_swipes)
    invalidated_ids = correction_invalidated_swipe_ids(correction)
    existing_items = Array(day_swipes).filter_map do |swipe|
      invalidated = invalidated_ids.include?(swipe.id.to_s)
      next if admin_correction_created_swipe?(correction, swipe)
      next if swipe.removed? && !invalidated

      admin_existing_correction_change_item(swipe, invalidated: invalidated)
    end

    (existing_items + admin_requested_correction_change_items(correction)).sort_by do |item|
      [ item[:minutes], admin_correction_change_item_sort_order(item) ]
    end
  end

  def admin_correction_change_icon_name(item)
    return "trash-2" if item[:type] == "invalidate"

    clocking_icon_name(item[:kind] || item[:type])
  end

  def admin_correction_change_icon_title(item)
    return t("admin.corrections.index.summary.invalidate") if item[:type] == "invalidate"
    return t("admin.corrections.index.summary.existing", kind: clocking_kind_text(item[:kind])) if item[:type] == "existing"

    clocking_kind_text(item[:kind])
  end

  def admin_correction_change_item_label(item)
    "#{admin_correction_change_icon_title(item)} #{item[:time]}"
  end

  private

  def rounded_time_count(seconds, unit_seconds)
    [ (seconds.to_f / unit_seconds.to_i).round, 1 ].max
  end

  def admin_correction_created_swipe?(correction, swipe)
    swipe.forged? && swipe.metadata == "admin_correction:#{correction.id}"
  end

  def correction_invalidated_swipe_ids(correction)
    Array(correction.details&.fetch("invalidated_swipe_ids", nil)).compact_blank.map(&:to_s)
  end

  def admin_existing_correction_change_item(swipe, invalidated:)
    kind = swipe.kind.to_s
    {
      type: invalidated ? "invalidate" : "existing",
      kind: kind,
      time: l(swipe.swipe_at, format: :hour_minute),
      minutes: (swipe.swipe_at.seconds_since_midnight / 60).to_i
    }
  end

  def admin_requested_correction_change_items(correction)
    Array(correction.details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      kind = requested_swipe["kind"].to_s
      time = requested_swipe_time_text(requested_swipe)
      next unless Swipe.kinds.key?(kind) && time.present?

      {
        type: "requested",
        kind: kind,
        time: time,
        minutes: requested_swipe_minutes(requested_swipe)
      }
    end
  end

  def admin_correction_change_item_sort_order(item)
    {
      "existing" => 0,
      "invalidate" => 1,
      "requested" => 2
    }.fetch(item[:type], 3)
  end
end
