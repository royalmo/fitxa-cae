module Employee::CorrectionsHelper
  def correction_title(_correction)
    t("employee.correction_kinds.generic")
  end

  def correction_requested_text(correction, include_comments: true)
    requested_swipes = Array(correction.details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      kind = requested_swipe["kind"]
      time = requested_swipe_time_text(requested_swipe)
      next unless kind.present? && time.present?

      "#{clocking_kind_text(kind)} #{time}"
    rescue ArgumentError, TypeError
      nil
    end

    invalidated_count = Array(correction.details&.fetch("invalidated_swipe_ids", nil)).count
    parts = []
    parts << t("employee.corrections.summary.requested_swipes", swipes: requested_swipes.join(", ")) if requested_swipes.any?
    parts << t("employee.corrections.summary.invalidated_swipes", count: invalidated_count) if invalidated_count.positive?
    parts << correction.requester_comments if include_comments && correction.requester_comments.present?

    parts.presence&.join(" · ") || t("employee.corrections.summary.no_details")
  end

  def employee_correction_row_path(correction)
    return new_correction_path(day: correction.day.iso8601) if correction.pending?

    correction_path(correction)
  end

  def correction_change_items(correction, invalidated_swipes_by_id = {})
    invalidated_items = Array(correction.details&.fetch("invalidated_swipe_ids", nil)).filter_map do |swipe_id|
      swipe = invalidated_swipes_by_id[swipe_id.to_s]
      next unless swipe

      {
        type: "invalidate",
        time: l(swipe.swipe_at, format: :hour_minute),
        minutes: (swipe.swipe_at.seconds_since_midnight / 60).to_i
      }
    end

    requested_items = Array(correction.details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      kind = requested_swipe["kind"].to_s
      time = requested_swipe_time_text(requested_swipe)
      next unless Swipe.kinds.key?(kind) && time.present?

      {
        type: kind,
        time: time,
        minutes: requested_swipe_minutes(requested_swipe)
      }
    end

    (invalidated_items + requested_items).sort_by { |item| [ item[:minutes], item[:type] ] }
  end

  def correction_change_icon_name(item)
    return "trash-2" if item[:type] == "invalidate"

    clocking_icon_name(item[:type])
  end

  def correction_change_icon_title(item)
    return t("employee.corrections.new.remove_swipe") if item[:type] == "invalidate"

    clocking_kind_text(item[:type])
  end

  def correction_change_item_label(item)
    "#{correction_change_icon_title(item)} #{item[:time]}"
  end

  def correction_requester_comment_heading(correction)
    return t("employee.corrections.show.human_resources_comment") if correction_created_by_human_resources?(correction)

    t("employee.corrections.show.comment")
  end

  def correction_created_by_human_resources?(correction)
    correction.requester_type == "Manager"
  end

  def correction_show_status_text(correction)
    return correction_status_text(correction.status) unless correction_created_by_human_resources?(correction)

    if correction.approved?
      t("employee.corrections.statuses.created_by_human_resources")
    elsif correction.rejected?
      t("employee.corrections.statuses.created_and_rejected_by_human_resources")
    else
      correction_status_text(correction.status)
    end
  end

  def correction_status_text(status)
    t("employee.corrections.statuses.#{status}", default: status_text(status))
  end

  def correction_answered_at(correction)
    correction.updated_at if correction.approved? || correction.rejected?
  end

  def correction_status_icon_name(status)
    {
      "approved" => "thumbs-up",
      "rejected" => "thumbs-down",
      "pending" => "hourglass"
    }.fetch(status.to_s, "circle-help")
  end

  def correction_status_filter_label(status)
    "#{correction_status_filter_symbol(status)} #{status_text(status)}"
  end

  def correction_status_radio_label(status)
    t("employee.corrections.index.status_options.#{status}")
  end

  def correction_empty_message(selected_month, selected_status)
    return t("employee.corrections.index.empty") if selected_month == Time.zone.today.beginning_of_month

    if selected_status.present?
      t(
        "employee.corrections.index.empty_month_with_status",
        status: t("employee.corrections.index.empty_statuses.#{selected_status}")
      )
    else
      t("employee.corrections.index.empty_month")
    end
  end

  private

  def correction_status_filter_symbol(status)
    {
      "approved" => "👍",
      "rejected" => "👎",
      "pending" => "⌛"
    }.fetch(status.to_s, "•")
  end

  def requested_swipe_time_text(requested_swipe)
    requested_swipe["hour"].presence&.first(5)
  end

  def requested_swipe_minutes(requested_swipe)
    match = requested_swipe_time_text(requested_swipe).to_s.match(/\A(\d{1,2}):(\d{2})/)
    return Float::INFINITY unless match

    (match[1].to_i * 60) + match[2].to_i
  end
end
