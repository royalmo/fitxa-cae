class EmployeeWelcomeMailer < ApplicationMailer
  def welcome(employee)
    @employee = employee
    @employee_name = employee.full_name.presence || employee.first_name.presence || employee.national_id

    mail to: employee.email, subject: t(".subject")
  end
end
