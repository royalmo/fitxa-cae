class ProcessEmployeeBulkActionRunJob < ApplicationJob
  queue_as :default

  def perform(employee_bulk_action_run)
    return if employee_bulk_action_run.terminal?

    EmployeeBulkActions::Processor.new(employee_bulk_action_run).perform
  rescue StandardError => error
    employee_bulk_action_run&.mark_failed!(EmployeeBulkActions::Messages.error_message(error))
    report_bulk_action_error(error, employee_bulk_action_run) unless EmployeeBulkActions::Messages.expected_error?(error)
  end

  private

  def report_bulk_action_error(error, employee_bulk_action_run)
    ErrorNotifier.notify(
      error,
      data: {
        context: "employee_bulk_action_run",
        job_class: self.class.name,
        job_id: job_id,
        queue_name: queue_name,
        executions: executions,
        employee_bulk_action_run_id: employee_bulk_action_run&.id,
        kind: employee_bulk_action_run&.kind
      }.compact
    )
  end
end
