class Admin::EmployeeWelcomeEmailResendsController < Admin::BaseController
  def show
    employee_welcome_email_resend = current_manager.employee_welcome_email_resends.find(params[:id])

    render json: employee_welcome_email_resend_payload(employee_welcome_email_resend)
  end

  private

  def employee_welcome_email_resend_payload(employee_welcome_email_resend)
    {
      id: employee_welcome_email_resend.id,
      status: employee_welcome_email_resend.status,
      progress: employee_welcome_email_resend.progress,
      message: employee_welcome_email_resend.status_message,
      status_url: admin_employee_welcome_email_resend_path(employee_welcome_email_resend)
    }
  end
end
