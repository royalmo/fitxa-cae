class Admin::EmployeeBulkActionsController < Admin::BaseController
  class InvalidNationalIds < StandardError
    attr_reader :national_id

    def initialize(national_id = nil)
      @national_id = national_id
      super()
    end
  end

  class DuplicateNationalIds < StandardError
    attr_reader :national_id, :count

    def initialize(national_id, count)
      @national_id = national_id
      @count = count
      super()
    end
  end

  class NoAffectedEmployees < StandardError; end

  class InvalidBulkTags < StandardError; end

  class ConflictingBulkTags < StandardError; end

  ACTIVATION_ACTIONS = {
    "activate" => true,
    "deactivate" => false
  }.freeze

  def activation
  end

  def simulate_activation
    employees_by_national_id = Employee
      .where(national_id: national_ids_param)
      .pluck(:national_id, :active)
      .to_h

    render json: employees_by_national_id
  rescue InvalidNationalIds => error
    render json: { error: invalid_national_ids_error(error) }, status: :unprocessable_entity
  rescue DuplicateNationalIds => error
    render json: { error: duplicate_national_ids_error(error) }, status: :unprocessable_entity
  end

  def run_activation
    target_active = activation_target_active
    affected_scope = Employee
      .where(national_id: national_ids_param)
      .where(active: !target_active)
    affected_count = affected_scope.count
    raise NoAffectedEmployees if affected_count.zero?

    Employee.transaction do
      affected_scope.find_each { |employee| employee.update!(active: target_active) }
    end

    flash_key = target_active ? "admin.flash.employee_bulk_activated" : "admin.flash.employee_bulk_deactivated"

    redirect_to admin_employees_path, notice: t(flash_key, count: affected_count)
  rescue InvalidNationalIds => error
    redirect_to bulk_activation_admin_employees_path, alert: invalid_national_ids_error(error)
  rescue DuplicateNationalIds => error
    redirect_to bulk_activation_admin_employees_path, alert: duplicate_national_ids_error(error)
  rescue NoAffectedEmployees
    redirect_to bulk_activation_admin_employees_path, alert: t("admin.employee_bulk_actions.errors.no_affected_employees")
  rescue ActionController::ParameterMissing
    redirect_to bulk_activation_admin_employees_path, alert: t("admin.employee_bulk_actions.errors.invalid_request")
  end

  def tags
  end

  def simulate_tags
    render json: tag_simulation_payload
  rescue InvalidNationalIds => error
    render json: { error: invalid_national_ids_error(error) }, status: :unprocessable_entity
  rescue DuplicateNationalIds => error
    render json: { error: duplicate_national_ids_error(error) }, status: :unprocessable_entity
  rescue InvalidBulkTags
    render json: { error: t("admin.employee_bulk_actions.errors.invalid_tags") }, status: :unprocessable_entity
  rescue ConflictingBulkTags
    render json: { error: t("admin.employee_bulk_actions.errors.conflicting_tags") }, status: :unprocessable_entity
  end

  def run_tags
    simulation = tag_simulation
    raise NoAffectedEmployees if simulation.fetch(:affected_employee_ids).empty?

    apply_tag_changes(simulation)

    redirect_to admin_employees_path,
      notice: t("admin.flash.employee_bulk_tags_updated", count: simulation.fetch(:affected_employee_ids).size)
  rescue InvalidNationalIds => error
    redirect_to bulk_tags_admin_employees_path, alert: invalid_national_ids_error(error)
  rescue DuplicateNationalIds => error
    redirect_to bulk_tags_admin_employees_path, alert: duplicate_national_ids_error(error)
  rescue InvalidBulkTags
    redirect_to bulk_tags_admin_employees_path, alert: t("admin.employee_bulk_actions.errors.invalid_tags")
  rescue ConflictingBulkTags
    redirect_to bulk_tags_admin_employees_path, alert: t("admin.employee_bulk_actions.errors.conflicting_tags")
  rescue NoAffectedEmployees
    redirect_to bulk_tags_admin_employees_path, alert: t("admin.employee_bulk_actions.errors.no_affected_employees")
  end

  private

  def national_ids_param
    national_ids = params[:national_ids]
    raise InvalidNationalIds unless national_ids.is_a?(Array)
    raise InvalidNationalIds if national_ids.empty?

    normalized_national_ids = national_ids.map do |national_id|
      raise InvalidNationalIds.new(national_id.inspect) unless national_id.is_a?(String)

      normalized_national_id = Employee.normalize_national_id(national_id)
      invalid_national_id = normalized_national_id.blank? || !Employee.valid_national_id?(normalized_national_id)
      raise InvalidNationalIds.new(normalized_national_id || national_id) if invalid_national_id

      normalized_national_id
    end

    raise_duplicated_national_ids!(normalized_national_ids)

    normalized_national_ids
  end

  def activation_target_active
    action = params.require(:bulk_action).require(:action).to_s

    ACTIVATION_ACTIONS.fetch(action)
  rescue KeyError
    raise ActionController::ParameterMissing, :action
  end

  def invalid_national_ids_error(error)
    return t("admin.employee_bulk_actions.errors.invalid_national_ids") if error.national_id.blank?

    t("admin.employee_bulk_actions.errors.invalid_national_id", national_id: error.national_id)
  end

  def raise_duplicated_national_ids!(national_ids)
    counts = national_ids.tally
    duplicated_national_id = national_ids.find { |national_id| counts.fetch(national_id) > 1 }

    raise DuplicateNationalIds.new(duplicated_national_id, counts.fetch(duplicated_national_id)) if duplicated_national_id
  end

  def duplicate_national_ids_error(error)
    t("admin.employee_bulk_actions.errors.duplicate_national_id",
      national_id: error.national_id,
      count: error.count)
  end

  def tag_simulation_payload
    simulation = tag_simulation

    {
      total_count: simulation.fetch(:national_ids).size,
      found_count: simulation.fetch(:employee_ids).size,
      affected_count: simulation.fetch(:affected_employee_ids).size,
      tags: simulation.fetch(:selected_tags).map do |tag|
        {
          id: tag.id,
          count: simulation.fetch(:tag_counts_by_id).fetch(tag.id, 0),
          html: render_to_string(partial: "admin/tags/label", formats: [ :html ], locals: { tag: tag })
        }
      end
    }
  end

  def tag_simulation
    national_ids = national_ids_param
    add_tags = bulk_tags_param(:add_tag_ids)
    remove_tags = bulk_tags_param(:remove_tag_ids)
    raise InvalidBulkTags if add_tags.empty? && remove_tags.empty?

    raise ConflictingBulkTags if (add_tags.map(&:id) & remove_tags.map(&:id)).any?

    employees = Employee.where(national_id: national_ids)
    employees = employees.active unless include_inactive_bulk_tags?
    employee_ids = employees.pluck(:id)
    selected_tags = (add_tags + remove_tags).uniq

    existing_add_counts_by_employee_id = existing_tag_counts_by_employee_id(employee_ids, add_tags.map(&:id))
    add_affected_employee_ids = add_tags.empty? ? [] : employee_ids.select do |employee_id|
      existing_add_counts_by_employee_id.fetch(employee_id, 0) < add_tags.size
    end
    remove_affected_employee_ids = tagged_employee_ids(employee_ids, remove_tags.map(&:id))

    {
      national_ids: national_ids,
      employee_ids: employee_ids,
      add_tags: add_tags,
      remove_tags: remove_tags,
      selected_tags: selected_tags,
      affected_employee_ids: (add_affected_employee_ids + remove_affected_employee_ids).uniq,
      tag_counts_by_id: tag_counts_by_id(employee_ids, selected_tags.map(&:id))
    }
  end

  def bulk_tags_param(key)
    tag_ids = params.dig(:bulk_tags, key).to_a.compact_blank.map(&:to_i).uniq
    tags = Tag.active.where(id: tag_ids).order(:name, :id).to_a
    raise InvalidBulkTags if tags.size != tag_ids.size

    tags
  end

  def include_inactive_bulk_tags?
    ActiveModel::Type::Boolean.new.cast(params.dig(:bulk_tags, :include_inactive))
  end

  def existing_tag_counts_by_employee_id(employee_ids, tag_ids)
    return {} if employee_ids.empty? || tag_ids.empty?

    Employee
      .joins(:tags)
      .where(id: employee_ids, tags: { id: tag_ids })
      .group("employees.id")
      .count
  end

  def tagged_employee_ids(employee_ids, tag_ids)
    return [] if employee_ids.empty? || tag_ids.empty?

    Employee
      .joins(:tags)
      .where(id: employee_ids, tags: { id: tag_ids })
      .distinct
      .pluck(:id)
  end

  def tag_counts_by_id(employee_ids, tag_ids)
    return {} if employee_ids.empty? || tag_ids.empty?

    Tag
      .joins(:employees)
      .where(id: tag_ids, employees: { id: employee_ids })
      .group("tags.id")
      .count
  end

  def apply_tag_changes(simulation)
    Employee.transaction do
      employees = Employee.where(id: simulation.fetch(:employee_ids)).includes(:tags)
      simulation.fetch(:add_tags).each { |tag| add_tag_to_employees(employees, tag) }
      simulation.fetch(:remove_tags).each { |tag| remove_tag_from_employees(employees, tag) }
    end
  end

  def add_tag_to_employees(employees, tag)
    employees.each do |employee|
      employee.tags << tag unless employee.tags.include?(tag)
    end
  end

  def remove_tag_from_employees(employees, tag)
    employees.each do |employee|
      employee.tags.delete(tag) if employee.tags.include?(tag)
    end
  end
end
