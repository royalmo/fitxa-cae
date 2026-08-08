module EmployeeBulkActions
  class Activation < Base
    ACTIONS = {
      "activate" => true,
      "deactivate" => false
    }.freeze

    def self.from_params(params)
      new(
        action: action_from(params.dig(:bulk_action, :action)),
        national_ids: normalized_national_ids(params[:national_ids])
      )
    end

    def self.from_simulation_params(params)
      new(
        action: nil,
        national_ids: normalized_national_ids(params[:national_ids])
      )
    end

    def self.from_parameters(parameters)
      new(
        action: action_from(parameters.fetch("action")),
        national_ids: normalized_national_ids(parameters.fetch("national_ids"))
      )
    end

    def self.action_from(raw_action)
      action = raw_action.to_s
      raise Errors::InvalidRequest unless ACTIONS.key?(action)

      action
    end

    def initialize(action:, national_ids:)
      @action = action
      @national_ids = national_ids
    end

    def parameters
      {
        action: action,
        national_ids: national_ids
      }
    end

    def simulation_payload
      Employee
        .where(national_id: national_ids)
        .pluck(:national_id, :active)
        .to_h
    end

    def validate_enqueue!
      raise Errors::NoAffectedEmployees if affected_count.zero?
    end

    def perform(run)
      run.mark_running!(progress: 8)

      affected_employees = affected_scope.to_a
      raise Errors::NoAffectedEmployees if affected_employees.empty?

      affected_employees.each_with_index do |employee, index|
        employee.update!(active: target_active)
        update_collection_progress(run, index + 1, affected_employees.size)
      end

      run.mark_completed!(completed_message(affected_employees.size))
    end

    private

    attr_reader :action, :national_ids

    def affected_count
      affected_scope.count
    end

    def affected_scope
      Employee
        .where(national_id: national_ids)
        .where(active: !target_active)
        .order(:id)
    end

    def target_active
      ACTIONS.fetch(action)
    end

    def completed_message(count)
      flash_key = target_active ? "admin.flash.employee_bulk_activated" : "admin.flash.employee_bulk_deactivated"

      I18n.t(flash_key, count: count)
    end
  end
end
