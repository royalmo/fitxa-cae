class Admin::EmployeeBulkActionsController < Admin::BaseController
  BULK_ACTION_ERRORS = [
    EmployeeBulkActions::Errors::InvalidNationalIds,
    EmployeeBulkActions::Errors::DuplicateNationalIds,
    EmployeeBulkActions::Errors::NoAffectedEmployees,
    EmployeeBulkActions::Errors::InvalidRequest,
    EmployeeBulkActions::Errors::InvalidBulkTags,
    EmployeeBulkActions::Errors::ConflictingBulkTags
  ].freeze

  def activation
  end

  def simulate_activation
    render json: EmployeeBulkActions::Activation.from_simulation_params(params).simulation_payload
  rescue *BULK_ACTION_ERRORS => error
    render_bulk_action_error(error)
  end

  def run_activation
    action = EmployeeBulkActions::Activation.from_params(params)
    action.validate_enqueue!

    render json: employee_bulk_action_run_payload(enqueue_employee_bulk_action_run("activation", action.parameters)),
      status: :accepted
  rescue *BULK_ACTION_ERRORS => error
    render_bulk_action_error(error)
  end

  def tags
  end

  def simulate_tags
    render json: EmployeeBulkActions::Tags.from_params(params).simulation_payload
  rescue *BULK_ACTION_ERRORS => error
    render_bulk_action_error(error)
  end

  def run_tags
    action = EmployeeBulkActions::Tags.from_params(params)
    action.validate_enqueue!

    render json: employee_bulk_action_run_payload(enqueue_employee_bulk_action_run("tags", action.parameters)),
      status: :accepted
  rescue *BULK_ACTION_ERRORS => error
    render_bulk_action_error(error)
  end

  private

  def enqueue_employee_bulk_action_run(kind, parameters)
    current_manager.employee_bulk_action_runs.create!(kind: kind, parameters: parameters).tap do |employee_bulk_action_run|
      record_audit_action!(
        author: current_manager,
        recipient: current_manager,
        kind: "employee_bulk_action.enqueued",
        extra_info: audit_bulk_action_details(employee_bulk_action_run)
      )
      ProcessEmployeeBulkActionRunJob.perform_later(employee_bulk_action_run)
    end
  end

  def employee_bulk_action_run_payload(employee_bulk_action_run)
    {
      id: employee_bulk_action_run.id,
      kind: employee_bulk_action_run.kind,
      status: employee_bulk_action_run.status,
      progress: employee_bulk_action_run.progress,
      message: t("admin.employee_bulk_action_runs.statuses.#{employee_bulk_action_run.status}"),
      status_url: admin_employee_bulk_action_run_path(employee_bulk_action_run)
    }
  end

  def render_bulk_action_error(error)
    render json: { error: EmployeeBulkActions::Messages.error_message(error) }, status: :unprocessable_entity
  end
end
