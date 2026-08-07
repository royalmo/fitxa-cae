require "test_helper"

class EmployeeWelcomeDeliveryJobTest < ActiveJob::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "delivers welcome emails for employees with email addresses" do
    first_employee = create_employee(national_id: valid_dni(46_000_001), email: "ada@example.test")
    second_employee = create_employee(national_id: valid_dni(46_000_002), email: "laia@example.test")
    employee_without_email = create_employee(national_id: valid_dni(46_000_003), email: nil)

    assert_difference -> { ActionMailer::Base.deliveries.size }, 2 do
      EmployeeWelcomeDeliveryJob.perform_now([ first_employee.id, second_employee.id, employee_without_email.id ])
    end

    assert_equal [ "ada@example.test", "laia@example.test" ], ActionMailer::Base.deliveries.map { |mail| mail.to.first }.sort
    assert_equal [ I18n.t("employee_welcome_mailer.welcome.subject") ], ActionMailer::Base.deliveries.map(&:subject).uniq
  end
end
