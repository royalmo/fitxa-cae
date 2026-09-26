class ResendEmployeeWelcomeEmailJob < ApplicationJob
  queue_as :default

  def perform(employee_welcome_email_resend)
    return if employee_welcome_email_resend.terminal?

    employee_welcome_email_resend.mark_running!(progress: 25)
    employee = employee_welcome_email_resend.employee

    unless employee.welcome_email_resendable?
      employee_welcome_email_resend.mark_failed!(welcome_email_blocked_message(employee))
      return
    end

    employee_welcome_email_resend.update!(progress: 60)
    EmployeeWelcomeMailer.welcome(employee).deliver_now
    employee_welcome_email_resend.update!(progress: 90)
    record_audit_action!(employee_welcome_email_resend)
    employee_welcome_email_resend.mark_completed!(I18n.t("admin.employees.welcome_email.success"))
  rescue StandardError => error
    employee_welcome_email_resend&.mark_failed!(I18n.t("admin.employees.welcome_email.failure"))
    report_resend_error(error, employee_welcome_email_resend)
  end

  private

  def record_audit_action!(employee_welcome_email_resend)
    AuditAction.create!(
      author: employee_welcome_email_resend.manager,
      recipient: employee_welcome_email_resend.employee,
      kind: "employee.welcome_email_resent",
      extra_info: {
        email: employee_welcome_email_resend.email
      }
    )
  end

  def welcome_email_blocked_message(employee)
    I18n.t("admin.employees.welcome_email.#{employee.welcome_email_resend_blocked_reason_key}")
  end

  def report_resend_error(error, employee_welcome_email_resend)
    ErrorNotifier.notify(
      error,
      data: {
        context: "admin_employee_welcome_email_resend",
        job_class: self.class.name,
        job_id: job_id,
        queue_name: queue_name,
        executions: executions,
        employee_welcome_email_resend_id: employee_welcome_email_resend&.id,
        employee_id: employee_welcome_email_resend&.employee_id,
        manager_id: employee_welcome_email_resend&.manager_id
      }.compact
    )
  end
end
