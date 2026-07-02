require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  test "is valid with required fields and database defaults" do
    employee = Employee.create!(first_name: "Ada", national_id: valid_dni)

    assert_predicate employee, :active?
    assert_equal({}, employee.settings)
  end

  test "supports optional secure password login" do
    passwordless = create_employee
    employee = create_employee(national_id: valid_dni(12_345_679), password: "1234")

    assert_not_predicate passwordless, :password_login_enabled?
    assert_predicate employee, :password_login_enabled?
    assert employee.authenticate("1234")
    assert_not employee.authenticate("bad")
  end

  test "requires first name and national id" do
    employee = Employee.new

    assert_not employee.valid?
    assert_model_error employee, :first_name, :blank
    assert_model_error employee, :national_id, :blank
  end

  test "normalizes and accepts valid dni and nie values" do
    dni_employee = build_employee(national_id: " #{valid_dni.downcase} ")
    nie_employee = build_employee(national_id: valid_nie("Y"))

    assert_predicate dni_employee, :valid?
    assert_equal valid_dni, dni_employee.national_id
    assert_predicate nie_employee, :valid?
  end

  test "rejects invalid spanish national ids" do
    employee = build_employee(national_id: "12345678A")

    assert_not employee.valid?
    assert_model_error employee, :national_id, :invalid

    employee.national_id = "ABC"
    assert_not employee.valid?
    assert_model_error employee, :national_id, :invalid
  end

  test "connects to manager, swipes, corrections, tags and audit actions" do
    employee = create_employee
    manager = create_manager(employee: employee)
    tag = Tag.create!(name: "office", color: "#2563eb")
    employee.tags << tag
    swipe = Swipe.create!(employee: employee, swipe_at: Time.zone.local(2026, 6, 30, 8), kind: "entry")
    correction = SwipeCorrection.create!(employee: employee, requester: employee, day: Date.new(2026, 6, 30))
    audit_action = AuditAction.create!(author: employee, recipient: manager, kind: "employee.updated")

    assert_equal manager, employee.manager
    assert_includes employee.tags, tag
    assert_includes employee.swipes, swipe
    assert_includes employee.swipe_corrections, correction
    assert_includes employee.requested_swipe_corrections, correction
    assert_includes employee.authored_audit_actions, audit_action
  end

  test "generates hashes and validates login codes without storing plaintext code" do
    employee = create_employee

    with_secure_random_number(12_345) do
      code = employee.generate_login_code!(delivery_method: "sms")

      assert_equal "012345", code
      employee.reload
      assert_equal "sms", employee.settings.dig("login_code", "delivery_method")
      assert_not_includes employee.settings.to_s, "012345"
      assert employee.authenticate_login_code("012345")
      assert_not employee.authenticate_login_code("999999")
    end
  end

  test "rejects expired login codes" do
    employee = create_employee
    employee.generate_login_code!(delivery_method: "email", expires_at: 1.minute.ago)

    assert_not employee.authenticate_login_code("000000")
  end
end
