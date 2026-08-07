class EmployeeWelcomeDeliveryJob < ApplicationJob
  queue_as :default

  def perform(employee_ids)
    Employee.where(id: employee_ids).where.not(email: nil).find_each do |employee|
      next if employee.email.blank?

      EmployeeWelcomeMailer.welcome(employee).deliver_now
    rescue StandardError => error
      report_employee_delivery_error(error, employee)
    end
  end

  private

  def report_employee_delivery_error(error, employee)
    ErrorNotifier.notify(
      error,
      data: {
        context: "employee_welcome_delivery",
        job_class: self.class.name,
        job_id: job_id,
        queue_name: queue_name,
        executions: executions,
        employee_id: employee.id
      }.compact
    )
  end
end
