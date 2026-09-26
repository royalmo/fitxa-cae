require "test_helper"

class ResendEmployeeWelcomeEmailJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "delivers welcome email and records audit action" do
    manager = create_manager
    employee = create_employee(
      first_name: "Pau",
      last_name: "Costa",
      national_id: valid_dni(43_000_001),
      email: "pau@example.test",
      active: true
    )
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: manager,
      employee: employee,
      email: employee.email
    )

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      ResendEmployeeWelcomeEmailJob.perform_now(employee_welcome_email_resend)
    end

    employee_welcome_email_resend.reload
    assert_predicate employee_welcome_email_resend, :completed?
    assert_equal 100, employee_welcome_email_resend.progress
    assert_equal "Correu de benvinguda enviat.", employee_welcome_email_resend.result_message
    assert_equal [ "pau@example.test" ], ActionMailer::Base.deliveries.last.to

    audit_action = AuditAction.order(:id).last
    assert_equal "employee.welcome_email_resent", audit_action.kind
    assert_equal employee, audit_action.recipient
    assert_equal manager, audit_action.author
    assert_equal({ "email" => "pau@example.test" }, audit_action.extra_info)
  end

  test "marks run failed when employee is no longer eligible" do
    employee = create_employee(
      national_id: valid_dni(43_000_002),
      email: "pau@example.test",
      password: "1234"
    )
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: create_manager,
      employee: employee,
      email: employee.email
    )

    assert_no_difference -> { ActionMailer::Base.deliveries.size } do
      ResendEmployeeWelcomeEmailJob.perform_now(employee_welcome_email_resend)
    end

    employee_welcome_email_resend.reload
    assert_predicate employee_welcome_email_resend, :failed?
    assert_equal "Aquesta persona ja té una contrasenya configurada.", employee_welcome_email_resend.error_message
  end

  test "marks run failed and reports unexpected delivery errors" do
    employee = create_employee(
      national_id: valid_dni(43_000_003),
      email: "pau@example.test",
      active: true
    )
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: create_manager,
      employee: employee,
      email: employee.email
    )
    error = StandardError.new("SMTP timeout")
    mailer_singleton = class << EmployeeWelcomeMailer
      self
    end
    original_welcome = EmployeeWelcomeMailer.method(:welcome)

    begin
      with_error_notifications do |notifications|
        mailer_singleton.define_method(:welcome) { |_employee| raise error }

        ResendEmployeeWelcomeEmailJob.perform_now(employee_welcome_email_resend)

        assert_equal 1, notifications.size
        assert_equal error, notifications.first.fetch(:error)
        assert_equal "admin_employee_welcome_email_resend", notifications.first.dig(:data, :context)
        assert_equal employee.id, notifications.first.dig(:data, :employee_id)
      end
    ensure
      mailer_singleton.define_method(:welcome, original_welcome)
    end

    employee_welcome_email_resend.reload
    assert_predicate employee_welcome_email_resend, :failed?
    assert_equal 100, employee_welcome_email_resend.progress
    assert_equal "No s'ha pogut enviar el correu de benvinguda.", employee_welcome_email_resend.error_message
  end
end
