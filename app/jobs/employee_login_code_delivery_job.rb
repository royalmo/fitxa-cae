class EmployeeLoginCodeDeliveryJob < ApplicationJob
  queue_as :default

  def perform(employee, code, delivery_method)
    @employee = employee
    @delivery_method = delivery_method.to_s

    case @delivery_method
    when "sms"
      SmsArena.deliver_login_code(phone: @employee.phone, code: code)
    when "email"
      EmployeeLoginMailer.code(@employee, code).deliver_now
    else
      raise ArgumentError, "Unknown login code delivery method: #{@delivery_method}"
    end
  rescue StandardError => error
    @employee.clear_login_code! if @employee&.persisted?
    report_job_error(
      error,
      data: {
        context: "employee_login_code_delivery",
        delivery_method: @delivery_method,
        employee_id: @employee&.id
      }.compact
    )
    raise error
  end
end
