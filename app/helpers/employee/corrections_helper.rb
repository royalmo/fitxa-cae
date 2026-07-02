module Employee::CorrectionsHelper
  def correction_title(correction)
    t("employee.correction_kinds.#{correction_request_kind(correction)}", default: t("employee.correction_kinds.generic"))
  end

  def correction_requested_text(correction)
    requested_swipes = Array(correction.details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      kind = requested_swipe["kind"]
      swipe_at = Time.zone.parse(requested_swipe["swipe_at"].to_s)
      next unless kind.present? && swipe_at.present?

      "#{clocking_kind_text(kind)} #{l(swipe_at, format: :hour_minute)}"
    rescue ArgumentError
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

  def correction_request_kind(correction)
    correction.details&.fetch("request_kind", nil).presence || "generic"
  end
end
