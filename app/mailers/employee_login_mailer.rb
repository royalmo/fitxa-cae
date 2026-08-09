class EmployeeLoginMailer < ApplicationMailer
  def code(employee, code)
    @employee = employee
    @employee_name = employee.full_name.presence || employee.first_name.presence || employee.national_id
    @code = code
    @ttl_minutes = Employee::LOGIN_CODE_TTL.in_minutes.to_i
    @app_url = mailer_app_url

    mail to: employee.email, subject: t(".subject", app_name: app_name, code: code)
  end
end
