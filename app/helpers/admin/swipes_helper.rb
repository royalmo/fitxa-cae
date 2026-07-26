module Admin::SwipesHelper
  def admin_swipes_month_options
    I18n.t("date.month_names").each_with_index.filter_map do |month_name, month_number|
      [ month_name, month_number ] if month_number.positive?
    end
  end

  def admin_swipes_day_action_icon(day)
    day[:swipes].any? ? "pencil" : "plus"
  end

  def admin_swipes_review_modal_id(correction, action)
    "swipe_correction_#{action}_modal_#{correction.id}"
  end

  def admin_swipes_review_path(correction, action)
    action.to_sym == :approve ? approve_admin_correction_path(correction) : reject_admin_correction_path(correction)
  end

  def admin_swipes_review_button_class(action)
    class_names(
      "btn btn-sm admin-row-action",
      action.to_sym == :approve ? "btn-outline-success" : "btn-outline-danger"
    )
  end

  def admin_swipes_review_submit_class(action)
    class_names("btn", action.to_sym == :approve ? "btn-success" : "btn-danger")
  end

  def admin_swipes_review_swipes(swipes)
    swipes.select do |swipe|
      clocking_swipe_pending_requested?(swipe) || clocking_swipe_pending_invalidated?(swipe)
    end
  end

  def admin_correction_day_path(employee, day, correction = nil)
    return edit_admin_correction_path(correction) if correction

    new_admin_correction_path(employee_id: employee.id, day: day.iso8601)
  end
end
