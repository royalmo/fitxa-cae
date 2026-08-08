class Admin::ManagersController < Admin::BaseController
  MANAGERS_PER_PAGE = 20

  rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique

  def index
    @managers = paginate_admin_relation(
      filtered_managers.order(:last_name, :first_name, :email, :id),
      per_page: MANAGERS_PER_PAGE
    ).to_a
  end

  def new
    @manager = Manager.new(active: true)
  end

  def create
    @manager = Manager.new(manager_params)

    if @manager.save
      ManagerPasswordMailer.password_setup(@manager).deliver_later
      record_audit_action!(
        author: current_manager,
        recipient: @manager,
        kind: "manager.created",
        extra_info: manager_created_audit_details(@manager, password_setup_email_enqueued: true)
      )
      redirect_to admin_managers_path, notice: t("admin.flash.manager_created")
    else
      render_manager_form(:new)
    end
  end

  def edit
    @manager = Manager.find(params[:id])
  end

  def update
    @manager = Manager.find(params[:id])
    attributes = manager_params

    if self_deactivation_attempt?(@manager, attributes)
      @manager.assign_attributes(attributes)
      @manager.active = true
      @manager.errors.add(:active, :self_deactivation)
      render_manager_form(:edit)
    elsif @manager.update(attributes)
      record_manager_update_audit(@manager)
      redirect_to admin_managers_path, notice: t("admin.flash.manager_updated")
    else
      render_manager_form(:edit)
    end
  end

  def activation
    @manager = Manager.find(params[:id])
    target_active = ActiveModel::Type::Boolean.new.cast(manager_activation_params[:active])

    if self_deactivation_attempt?(@manager, active: target_active)
      redirect_back fallback_location: admin_managers_path, alert: t("admin.flash.manager_self_deactivation_blocked")
    elsif @manager.update(active: target_active)
      record_manager_activation_audit(@manager) if @manager.saved_change_to_active?
      redirect_back fallback_location: admin_managers_path,
        notice: t(target_active ? "admin.flash.manager_activated" : "admin.flash.manager_deactivated")
    else
      redirect_back fallback_location: admin_managers_path, alert: t("admin.flash.manager_activation_failed")
    end
  end

  private

  def render_manager_form(template)
    render template, status: :unprocessable_entity
  end

  def handle_record_not_unique(error)
    @manager ||= params[:id].present? ? Manager.find(params[:id]) : Manager.new
    @manager.assign_attributes(manager_params)
    @manager.errors.add(record_not_unique_attribute(error), :taken)
    render_manager_form(@manager.persisted? ? :edit : :new)
  end

  def record_not_unique_attribute(error)
    error.message.include?("index_managers_on_lower_email") ? :email : :employee_id
  end

  def self_deactivation_attempt?(manager, attributes)
    return false unless manager.id == current_manager&.id
    return false unless attributes.key?(:active) || attributes.key?("active")

    !ActiveModel::Type::Boolean.new.cast(attributes[:active])
  end

  def filtered_managers
    managers = Manager.all
    managers = managers.where(active: true) if params[:status] == "active"
    managers = managers.where(active: false) if params[:status] == "disabled"

    if params[:q].present?
      query = "%#{params[:q].to_s.downcase}%"
      managers = managers.where(
        "LOWER(first_name) LIKE :query OR LOWER(last_name) LIKE :query OR LOWER(email) LIKE :query",
        query: query
      )
    end

    managers
  end

  def manager_params
    attributes = params.require(:manager).permit(:first_name, :last_name, :email, :employee_id, :active)
    attributes[:employee_id] = nil if attributes[:employee_id].blank?
    attributes
  end

  def manager_activation_params
    params.require(:manager).permit(:active)
  end

  def manager_created_audit_details(manager, password_setup_email_enqueued:)
    changes = audit_saved_changes(manager, fields: %w[first_name last_name email employee_id active])

    {
      changed_fields: audit_changed_fields(changes),
      changes: changes,
      password_setup_email_enqueued: password_setup_email_enqueued
    }
  end

  def record_manager_update_audit(manager)
    changes = audit_saved_changes(manager, fields: %w[first_name last_name email employee_id active])
    active_changed = changes.delete("active")

    record_manager_activation_audit(manager) if active_changed

    record_audit_update!(
      author: current_manager,
      recipient: manager,
      kind: "manager.updated",
      changes: changes
    )
  end

  def record_manager_activation_audit(manager)
    previous_active, active = manager.saved_change_to_active

    record_audit_action!(
      author: current_manager,
      recipient: manager,
      kind: active ? "manager.activated" : "manager.deactivated",
      extra_info: {
        changed_fields: [ "active" ],
        changes: { active: { from: previous_active, to: active } }
      }
    )
  end
end
