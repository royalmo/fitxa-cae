module EmployeeBulkActions
  class Processor
    def initialize(employee_bulk_action_run)
      @employee_bulk_action_run = employee_bulk_action_run
    end

    def perform
      action.perform(employee_bulk_action_run)
    end

    private

    attr_reader :employee_bulk_action_run

    def action
      case employee_bulk_action_run.kind
      when "activation"
        Activation.from_parameters(employee_bulk_action_run.parameters)
      when "tags"
        Tags.from_parameters(employee_bulk_action_run.parameters)
      when "import"
        Import.from_parameters(employee_bulk_action_run.parameters)
      else
        raise ActiveRecord::RecordInvalid, employee_bulk_action_run
      end
    end
  end
end
