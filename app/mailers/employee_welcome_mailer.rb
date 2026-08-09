class EmployeeWelcomeMailer < ApplicationMailer
  def welcome(employee)
    @employee = employee
    @employee_name = employee.full_name.presence || employee.first_name.presence || employee.national_id
    @app_url = mailer_app_url
    @password_url = employee_password_setup_url(employee.password_setup_token)

    mail to: employee.email, subject: t(".subject")
  end
end
