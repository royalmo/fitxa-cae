class Admin::ImportsController < Admin::BaseController
  IMPORT_ERRORS = [
    EmployeeBulkActions::Errors::InvalidImport,
    EmployeeBulkActions::Errors::InvalidImportTags
  ].freeze

  def new
  end

  def simulate
    render json: EmployeeBulkActions::Import.from_params(params).simulation_payload
  rescue *IMPORT_ERRORS => error
    render_import_error(error)
  end

  def create
    action = EmployeeBulkActions::Import.from_params(params)
    action.validate_enqueue!

    render json: employee_bulk_action_run_payload(enqueue_employee_bulk_action_run(action.parameters)), status: :accepted
  rescue *IMPORT_ERRORS => error
    render_import_error(error)
  end

  private

  def enqueue_employee_bulk_action_run(parameters)
    current_manager.employee_bulk_action_runs.create!(kind: "import", parameters: parameters).tap do |employee_bulk_action_run|
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

  def render_import_error(error)
    render json: { error: EmployeeBulkActions::Messages.error_message(error) }, status: :unprocessable_entity
  end
end
