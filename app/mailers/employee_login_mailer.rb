class EmployeeLoginMailer < ApplicationMailer
  def code(employee, code)
    @employee = employee
    @code = code
    @ttl_minutes = Employee::LOGIN_CODE_TTL.in_minutes.to_i

    mail to: employee.email, subject: t(".subject")
  end
end
