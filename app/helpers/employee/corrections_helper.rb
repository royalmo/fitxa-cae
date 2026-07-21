module Employee::CorrectionsHelper
  def correction_title(_correction)
    t("employee.correction_kinds.generic")
  end

  def correction_requested_text(correction)
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
    parts << correction.requester_comments if correction.requester_comments.present?

    parts.presence&.join(" · ") || t("employee.corrections.summary.no_details")
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
end
