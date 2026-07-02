require "test_helper"

class Employee::AccountsControllerTest < ActionDispatch::IntegrationTest
  test "shows persisted account details" do
    employee = create_employee(password: "1234", email: "ada@example.test", phone: "+34 600 111 222")
    employee.tags.create!(name: "office", active: true, color: "#2563eb")
    log_in_employee(employee)

    get account_path

    assert_response :success
    assert_match "ada@example.test", response.body
    assert_match "+34 600 111 222", response.body
    assert_match "office", response.body
  end

  test "updates contact details" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    patch account_path, params: {
      email: "new@example.test",
      phone: "+34 611 222 333"
    }

    assert_redirected_to account_path
    employee.reload
    assert_equal "new@example.test", employee.email
    assert_equal "+34 611 222 333", employee.phone
  end

  test "requires current password to change an existing password" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    patch account_path, params: {
      current_password: "bad",
      password: "5678",
      password_confirmation: "5678"
    }

    assert_response :unprocessable_entity
    assert employee.reload.authenticate("1234")
    assert_not employee.authenticate("5678")
  end

  test "changes password when current password and confirmation are valid" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    patch account_path, params: {
      current_password: "1234",
      password: "5678",
      password_confirmation: "5678"
    }

    assert_redirected_to account_path
    assert employee.reload.authenticate("5678")
  end
end
