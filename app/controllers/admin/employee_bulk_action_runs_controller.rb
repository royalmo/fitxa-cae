class Admin::EmployeeBulkActionRunsController < Admin::BaseController
  def show
    employee_bulk_action_run = current_manager.employee_bulk_action_runs.find(params[:id])

    render json: employee_bulk_action_run_payload(employee_bulk_action_run)
  end

  private

  def employee_bulk_action_run_payload(employee_bulk_action_run)
    {
      id: employee_bulk_action_run.id,
      kind: employee_bulk_action_run.kind,
      status: employee_bulk_action_run.status,
      progress: employee_bulk_action_run.progress,
      message: employee_bulk_action_run_message(employee_bulk_action_run),
      status_url: admin_employee_bulk_action_run_path(employee_bulk_action_run)
    }
  end

  def employee_bulk_action_run_message(employee_bulk_action_run)
    return employee_bulk_action_run.error_message if employee_bulk_action_run.failed?
    return employee_bulk_action_run.result_message if employee_bulk_action_run.completed?

    t("admin.employee_bulk_action_runs.statuses.#{employee_bulk_action_run.status}")
  end
end
