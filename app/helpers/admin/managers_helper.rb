module Admin::ManagersHelper
  def admin_manager_status(manager)
    manager.active? ? :active : :disabled
  end

  def admin_manager_status_icon(status)
    status.to_sym == :active ? "circle-check" : "circle-off"
  end

  def admin_manager_status_icon_class(status)
    class_names(
      "admin-manager-status-icon",
      "is-active": status.to_sym == :active,
      "is-inactive": status.to_sym == :disabled
    )
  end

  def admin_manager_activation_action(manager)
    manager.active? ? :deactivate : :activate
  end

  def admin_manager_activation_icon(manager)
    manager.active? ? "circle-off" : "circle-check"
  end

  def admin_manager_activation_modal_id(manager)
    "manager_activation_modal_#{manager.id}"
  end

  def admin_manager_self?(manager)
    manager.persisted? && manager.id == current_manager&.id
  end

  def admin_manager_self_deactivation_disabled?(manager)
    admin_manager_self?(manager) && manager.active?
  end

  def admin_manager_active_option_disabled?(manager, value)
    admin_manager_self?(manager) && ActiveModel::Type::Boolean.new.cast(value) == false
  end

  def admin_manager_activation_button_title(manager, action)
    return t("admin.managers.activation.self_deactivation_disabled") if admin_manager_self_deactivation_disabled?(manager)

    t("admin.managers.activation.#{action}.button", name: manager_display_name(manager))
  end

  def admin_manager_activation_button_class(manager)
    class_names(
      "btn btn-sm admin-row-action",
      manager.active? ? "btn-outline-secondary" : "btn-outline-success"
    )
  end

  def admin_manager_activation_submit_class(action)
    class_names("btn", action.to_sym == :deactivate ? "btn-danger" : "btn-primary")
  end

  def admin_manager_last_access_text(manager)
    last_request_at = manager.last_request_at
    return t("admin.managers.index.last_access_never") unless last_request_at

    seconds = [ (Time.current - last_request_at).to_i, 0 ].max

    case seconds
    when 0...60
      t("admin.managers.index.last_access_ago.less_than_minute")
    when 60...1.hour
      t("admin.managers.index.last_access_ago.minute", count: rounded_time_count(seconds, 1.minute))
    when 1.hour...1.day
      t("admin.managers.index.last_access_ago.hour", count: rounded_time_count(seconds, 1.hour))
    when 1.day...60.days
      t("admin.managers.index.last_access_ago.day", count: rounded_time_count(seconds, 1.day))
    when 60.days...2.years
      t("admin.managers.index.last_access_ago.month", count: rounded_time_count(seconds, 30.days))
    else
      t("admin.managers.index.last_access_ago.year", count: rounded_time_count(seconds, 1.year))
    end
  end

  private

  def rounded_time_count(seconds, unit_seconds)
    [ (seconds.to_f / unit_seconds.to_i).round, 1 ].max
  end
end
