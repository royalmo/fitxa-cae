require "test_helper"

class EmployeeLoginCodeDeliveryJobTest < ActiveJob::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "delivers email login codes inside the job" do
    employee = create_employee(email: "ada@example.test")

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      EmployeeLoginCodeDeliveryJob.perform_now(employee, "123456", "email")
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "ada@example.test" ], mail.to
    assert_match "123456", mail.text_part.body.decoded
  end

  test "delivers sms login codes inside the job" do
    employee = create_employee(phone: "+34 600 111 222")
    deliveries = []

    with_sms_delivery(->(phone:, code:) {
      deliveries << { phone: phone, code: code }
    }) do
      EmployeeLoginCodeDeliveryJob.perform_now(employee, "123456", "sms")
    end

    assert_equal [ { phone: "+34 600 111 222", code: "123456" } ], deliveries
  end

  test "reports and clears login code after delivery failure" do
    employee = create_employee(phone: "+34 600 111 222")
    employee.generate_login_code!(delivery_method: "sms")
    response = Struct.new(:code).new(500)

    with_sms_delivery(->(**_kwargs) { raise SmsArena::DeliveryError, response }) do
      with_error_notifications do |notifications|
        assert_raises(SmsArena::DeliveryError) do
          EmployeeLoginCodeDeliveryJob.perform_now(employee, "123456", "sms")
        end

        assert_nil employee.reload.settings["login_code"]
        assert_equal 1, notifications.size
        assert_equal "employee_login_code_delivery", notifications.first[:data][:context]
        assert_equal "sms", notifications.first[:data][:delivery_method]
        assert_equal employee.id, notifications.first[:data][:employee_id]
      end
    end
  end

  private

  def with_sms_delivery(delivery)
    singleton = class << SmsArena
      self
    end
    original_method = SmsArena.method(:deliver_login_code)

    singleton.define_method(:deliver_login_code, &delivery)
    yield
  ensure
    singleton.define_method(:deliver_login_code, original_method) if original_method
  end
end
