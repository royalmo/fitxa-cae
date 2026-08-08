class Admin::EmployeesController < Admin::BaseController
  EMPLOYEES_PER_PAGE = 20

  def index
    @selected_tag = selected_tag
    @employees = paginate_admin_relation(
      filtered_employees.order(:last_name, :first_name, :id),
      per_page: EMPLOYEES_PER_PAGE
    ).includes(:tags).to_a
    employee_ids = @employees.map(&:id)
    @last_swipes_by_employee_id = last_swipes_by_employee_id(employee_ids)
  end

  def new
    @employee = Employee.new(active: true)
    load_tags
  end

  def create
    @employee = Employee.new(employee_params)
    @employee.active = true
    @employee.tag_ids = selected_tag_ids

    if @employee.save
      welcome_email_enqueued = deliver_employee_welcome(@employee)
      record_audit_action!(
        author: current_manager,
        recipient: @employee,
        kind: "employee.created",
        extra_info: employee_created_audit_details(@employee, welcome_email_enqueued: welcome_email_enqueued)
      )
      redirect_to admin_employees_path, notice: t("admin.flash.employee_created")
    else
      load_tags
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @employee = Employee.find(params[:id])
    load_tags
  end

  def update
    @employee = Employee.find(params[:id])
    previous_tag_ids = @employee.tag_ids
    @employee.assign_attributes(employee_params)
    @employee.tag_ids = selected_tag_ids

    if @employee.save
      record_employee_update_audit(@employee, previous_tag_ids)
      redirect_to admin_employees_path, notice: t("admin.flash.employee_updated")
    else
      load_tags
      render :edit, status: :unprocessable_entity
    end
  end

  def activation
    @employee = Employee.find(params[:id])
    target_active = ActiveModel::Type::Boolean.new.cast(employee_activation_params[:active])

    if @employee.update(active: target_active)
      record_employee_activation_audit(@employee) if @employee.saved_change_to_active?
      redirect_back fallback_location: admin_employees_path,
        notice: t(target_active ? "admin.flash.employee_activated" : "admin.flash.employee_deactivated")
    else
      redirect_back fallback_location: admin_employees_path, alert: t("admin.flash.employee_activation_failed")
    end
  end

  private

  def filtered_employees
    employees = Employee.all
    employees = employees.where(active: true) if params[:status] == "active"
    employees = employees.where(active: false) if params[:status] == "disabled"
    employees = employees.joins(:tags).where(tags: { id: @selected_tag.id }) if @selected_tag

    if params[:q].present?
      query = "%#{params[:q].to_s.downcase}%"
      employees = employees.where(
        "LOWER(first_name) LIKE :query OR LOWER(last_name) LIKE :query OR LOWER(email) LIKE :query OR LOWER(national_id) LIKE :query",
        query: query
      )
    end

    employees.distinct
  end

  def selected_tag
    Tag.find_by(id: params[:tag_id].presence) if params[:tag_id].present?
  end

  def employee_params
    params.require(:employee).permit(:first_name, :last_name, :national_id, :email, :phone, :active)
  end

  def employee_activation_params
    params.require(:employee).permit(:active)
  end

  def selected_tag_ids
    params.dig(:employee, :tag_ids).to_a.compact_blank
  end

  def load_tags
    @tags = Tag.order(:name)
  end

  def deliver_employee_welcome(employee)
    return false if employee.email.blank?

    EmployeeWelcomeMailer.welcome(employee).deliver_later
    true
  end

  def last_swipes_by_employee_id(employee_ids)
    Swipe.kept
      .where(employee_id: employee_ids)
      .order(swipe_at: :desc, id: :desc)
      .group_by(&:employee_id)
      .transform_values(&:first)
  end

  def employee_created_audit_details(employee, welcome_email_enqueued:)
    changes = audit_saved_changes(employee, fields: %w[first_name last_name national_id email phone active])
    tag_ids = employee.tag_ids

    {
      changed_fields: audit_changed_fields(changes),
      changes: changes,
      tag_ids: tag_ids,
      tags: audit_tag_names(tag_ids),
      welcome_email_enqueued: welcome_email_enqueued
    }
  end

  def record_employee_update_audit(employee, previous_tag_ids)
    changes = audit_saved_changes(employee, fields: %w[first_name last_name national_id email phone active])
    active_changed = changes.delete("active")
    next_tag_ids = employee.tag_ids

    record_employee_activation_audit(employee) if active_changed

    if previous_tag_ids.sort != next_tag_ids.sort
      changes["tags"] = {
        "from" => audit_tag_names(previous_tag_ids),
        "to" => audit_tag_names(next_tag_ids)
      }
    end

    record_audit_update!(
      author: current_manager,
      recipient: employee,
      kind: "employee.updated",
      changes: changes,
      extra_info: audit_tag_change_details(previous_tag_ids, next_tag_ids)
    )
  end

  def record_employee_activation_audit(employee)
    previous_active, active = employee.saved_change_to_active

    record_audit_action!(
      author: current_manager,
      recipient: employee,
      kind: active ? "employee.activated" : "employee.deactivated",
      extra_info: {
        changed_fields: [ "active" ],
        changes: { active: { from: previous_active, to: active } }
      }
    )
  end
end
