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

    affected_scope.update_all(active: target_active, updated_at: Time.current)

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
end
