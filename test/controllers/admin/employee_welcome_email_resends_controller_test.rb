require "test_helper"

class Admin::EmployeeWelcomeEmailResendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @manager = create_manager
    log_in_manager(@manager)
  end

  test "returns welcome email resend status for current manager" do
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: @manager,
      employee: create_employee(email: "ada@example.test"),
      email: "ada@example.test"
    )
    employee_welcome_email_resend.mark_running!(progress: 25)

    get admin_employee_welcome_email_resend_path(employee_welcome_email_resend), as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal employee_welcome_email_resend.id, payload.fetch("id")
    assert_equal "running", payload.fetch("status")
    assert_equal 25, payload.fetch("progress")
    assert_equal "Enviant el correu de benvinguda...", payload.fetch("message")
    assert_equal admin_employee_welcome_email_resend_path(employee_welcome_email_resend), payload.fetch("status_url")
  end

  test "does not expose another manager welcome email resend status" do
    employee_welcome_email_resend = EmployeeWelcomeEmailResend.create!(
      manager: create_manager,
      employee: create_employee(email: "ada@example.test"),
      email: "ada@example.test"
    )

    get admin_employee_welcome_email_resend_path(employee_welcome_email_resend), as: :json

    assert_response :not_found
  end
end
