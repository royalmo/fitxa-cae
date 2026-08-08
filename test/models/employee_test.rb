require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  test "is valid with required fields and database defaults" do
    employee = Employee.create!(first_name: "Ada", national_id: valid_dni)

    assert_predicate employee, :active?
    assert_equal({}, employee.settings)
    assert_equal "system", employee.theme_preference
  end

  test "creates an open employment period for active employees" do
    employee = nil

    travel_to Time.zone.local(2026, 7, 1, 8, 0) do
      employee = create_employee(active: true)
    end

    period = employee.reload.employment_periods.sole
    assert_equal employee.created_at, period.started_at
    assert_nil period.ended_at
  end

  test "does not create an employment period for inactive employees" do
    employee = create_employee(active: false)

    assert_empty employee.employment_periods
  end

  test "stores theme preference in settings" do
    employee = create_employee

    employee.theme_preference = "dark"

    assert_equal "dark", employee.theme_preference
    assert_equal "dark", employee.settings["theme"]

    employee.theme_preference = "invalid"

    assert_equal "system", employee.theme_preference
    assert_equal "system", employee.settings["theme"]
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

  test "locks national id changes 24 hours after creation" do
    created_at = Time.zone.local(2026, 7, 1, 8, 0, 0)
    employee = nil

    travel_to created_at do
      employee = create_employee(national_id: valid_dni(12_345_678))
    end

    travel_to employee.created_at + 23.hours + 59.minutes do
      assert_not_predicate employee, :national_id_locked?
      assert employee.update(national_id: valid_dni(12_345_679))
    end

    travel_to employee.created_at + 24.hours do
      assert_predicate employee, :national_id_locked?
      employee.national_id = valid_dni(12_345_680)

      assert_not employee.valid?
      assert_model_error employee, :national_id, :locked_after_creation
    end
  end

  test "closes and creates employment periods for activation changes after the undo window" do
    employee = nil

    travel_to Time.zone.local(2026, 7, 1, 8, 0) do
      employee = create_employee(active: true)
    end

    travel_to Time.zone.local(2026, 7, 3, 9, 0) do
      employee.update!(active: false)
    end

    first_period = employee.reload.employment_periods.sole
    assert_not first_period.open?
    assert_equal employee.updated_at, first_period.ended_at

    travel_to Time.zone.local(2026, 7, 5, 10, 0) do
      employee.update!(active: true)
    end

    periods = employee.reload.employment_periods.chronological.to_a
    assert_equal 2, periods.size
    assert_not periods.first.open?
    assert_predicate periods.second, :open?
    assert_equal employee.updated_at, periods.second.started_at
  end

  test "reactivating within the undo window reopens the latest period" do
    employee = nil

    travel_to Time.zone.local(2026, 7, 1, 8, 0) do
      employee = create_employee(active: true)
    end

    travel_to Time.zone.local(2026, 7, 3, 9, 0) do
      employee.update!(active: false)
    end

    closed_period_id = employee.reload.employment_periods.sole.id

    travel_to Time.zone.local(2026, 7, 3, 18, 0) do
      employee.update!(active: true)
    end

    period = employee.reload.employment_periods.sole
    assert_equal closed_period_id, period.id
    assert_predicate period, :open?
  end

  test "deactivating within the undo window removes a short activation period" do
    employee = create_employee(active: false)
    original_period = employee.employment_periods.create!(
      started_at: Time.zone.local(2026, 6, 1),
      ended_at: Time.zone.local(2026, 6, 30)
    )

    travel_to Time.zone.local(2026, 7, 3, 9, 0) do
      employee.update!(active: true)
    end

    assert_equal 2, employee.reload.employment_periods.count
    assert_predicate employee.current_employment_period, :open?

    travel_to Time.zone.local(2026, 7, 3, 18, 0) do
      employee.update!(active: false)
    end

    periods = employee.reload.employment_periods.to_a
    assert_equal [ original_period.id ], periods.map(&:id)
    assert_nil employee.current_employment_period
  end

  test "active during returns employees with employment periods overlapping the range" do
    range = Time.zone.local(2026, 7, 1)...Time.zone.local(2026, 8, 1)
    active_in_month = create_employee(national_id: valid_dni(12_345_690), active: false)
    active_in_month.employment_periods.create!(
      started_at: Time.zone.local(2026, 6, 20),
      ended_at: Time.zone.local(2026, 7, 10)
    )
    active_after_month = create_employee(national_id: valid_dni(12_345_691), active: false)
    active_after_month.employment_periods.create!(
      started_at: Time.zone.local(2026, 8, 1),
      ended_at: Time.zone.local(2026, 8, 10)
    )

    employees = Employee.active_during(range)

    assert_includes employees, active_in_month
    assert_not_includes employees, active_after_month
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

  test "only an entry from the current day counts as open" do
    employee = create_employee
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8), metadata: "employee_portal")

    assert employee.clocked_in?(at: Time.zone.local(2026, 7, 2, 12))
    assert_not employee.clocked_in?(at: Time.zone.local(2026, 7, 3, 8))
    assert_nil employee.open_entry_swipe(at: Time.zone.local(2026, 7, 3, 8))
  end

  test "generates hashes and validates login codes without storing plaintext code" do
    employee = create_employee

    with_secure_random_number(12_345) do
      code = employee.generate_login_code!(delivery_method: "sms")

      assert_equal "123456", code
      employee.reload
      assert_equal "sms", employee.settings.dig("login_code", "delivery_method")
      assert_equal Employee::LOGIN_CODE_CHECKSUM, employee.settings.dig("login_code", "checksum")
      assert_not_includes employee.settings.to_s, "123456"
      assert employee.authenticate_login_code("123456")
      assert employee.authenticate_login_code("123 456")
      assert_not employee.authenticate_login_code("123455")
      assert_not employee.authenticate_login_code("999999")
    end
  end

  test "validates login code checksum" do
    assert Employee.valid_login_code_checksum?("123456")
    assert Employee.valid_login_code_checksum?("000422")
    assert_not Employee.valid_login_code_checksum?("123455")
    assert_not Employee.valid_login_code_checksum?("132456")
    assert_not Employee.valid_login_code_checksum?("12345")
  end

  test "rejects expired login codes" do
    employee = create_employee
    employee.generate_login_code!(delivery_method: "email", expires_at: 1.minute.ago)

    assert_not employee.authenticate_login_code("000000")
  end

  test "reports login code rate limit reason" do
    employee = create_employee
    requested_at = Time.zone.local(2026, 8, 8, 10, 0)

    assert_nil employee.login_code_rate_limit_reason(now: requested_at)

    employee.generate_login_code!(delivery_method: "email", requested_at: requested_at)
    assert_equal "cooldown", employee.reload.login_code_rate_limit_reason(now: requested_at + 30.seconds)

    (Employee::LOGIN_CODE_LIMIT - 1).times do |index|
      employee.generate_login_code!(
        delivery_method: "email",
        requested_at: requested_at + ((index + 1) * (Employee::LOGIN_CODE_COOLDOWN + 1.second))
      )
    end

    assert_equal "request_limit",
      employee.reload.login_code_rate_limit_reason(now: requested_at + 5.minutes)
  end
end
