require "test_helper"

class EmployeeWelcomeEmailResendTest < ActiveSupport::TestCase
  test "defaults to queued with zero progress" do
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: create_manager,
      employee: create_employee(email: "ada@example.test"),
      email: "ada@example.test"
    )

    assert_predicate employee_welcome_email_resend, :queued?
    assert_equal 0, employee_welcome_email_resend.progress
    assert_equal "Enviament pendent...", employee_welcome_email_resend.status_message
  end

  test "marks run lifecycle states" do
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: create_manager,
      employee: create_employee(email: "ada@example.test"),
      email: "ada@example.test"
    )

    employee_welcome_email_resend.mark_running!(progress: 60)

    assert_predicate employee_welcome_email_resend, :running?
    assert_equal 60, employee_welcome_email_resend.progress
    assert_equal "Enviant el correu de benvinguda...", employee_welcome_email_resend.status_message

    employee_welcome_email_resend.mark_completed!("Fet")

    assert_predicate employee_welcome_email_resend, :completed?
    assert_predicate employee_welcome_email_resend, :terminal?
    assert_equal 100, employee_welcome_email_resend.progress
    assert_equal "Fet", employee_welcome_email_resend.status_message
    assert_not_nil employee_welcome_email_resend.completed_at
  end

  test "marks failed with a generic fallback message" do
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: create_manager,
      employee: create_employee(email: "ada@example.test"),
      email: "ada@example.test"
    )

    employee_welcome_email_resend.mark_failed!("")

    assert_predicate employee_welcome_email_resend, :failed?
    assert_predicate employee_welcome_email_resend, :terminal?
    assert_equal 100, employee_welcome_email_resend.progress
    assert_equal "No s'ha pogut enviar el correu de benvinguda.", employee_welcome_email_resend.status_message
    assert_not_nil employee_welcome_email_resend.failed_at
  end
end
