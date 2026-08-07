require "test_helper"

class ManagerTest < ActiveSupport::TestCase
  test "is valid without an employee and defaults to active" do
    manager = Manager.create!(first_name: "Laia", last_name: "Riera", email: "laia.riera@example.test")

    assert_predicate manager, :active?
    assert_nil manager.employee
  end

  test "requires a unique email" do
    create_manager(email: "laia.riera@example.test")

    manager = Manager.new(first_name: "Laia", last_name: "Riera")
    assert_not manager.valid?
    assert_model_error manager, :email, :blank

    manager.email = " LAIA.RIERA@EXAMPLE.TEST "
    assert_not manager.valid?
    assert_model_error manager, :email, :taken
  end

  test "can be linked to one employee" do
    employee = create_employee
    manager = create_manager(employee: employee)

    assert_equal employee, manager.employee
    assert_equal manager, employee.manager
  end

  test "does not allow linking one employee to multiple managers" do
    employee = create_employee
    create_manager(employee: employee, email: "first.manager@example.test")
    manager = Manager.new(
      employee: employee,
      email: "second.manager@example.test",
      first_name: "Ona",
      last_name: "Prat",
      active: true
    )

    assert_not manager.valid?
    assert_model_error manager, :employee_id, :taken
    assert_equal "Persona vinculada ja està assignada a un altre responsable",
      manager.errors.full_messages_for(:employee_id).first
  end

  test "tracks requested and validated swipe corrections" do
    employee = create_employee
    manager = create_manager
    validated = SwipeCorrection.create!(
      employee: employee,
      requester: employee,
      validator: manager,
      status: "approved",
      day: Date.new(2026, 6, 29)
    )
    requested = SwipeCorrection.create!(
      employee: employee,
      requester: manager,
      day: Date.new(2026, 6, 30)
    )

    assert_includes manager.validated_swipe_corrections, validated
    assert_includes manager.requested_swipe_corrections, requested
  end

  test "requires active to be boolean when explicitly assigned" do
    manager = Manager.new(active: nil)

    assert_not manager.valid?
    assert_model_error manager, :active, :inclusion
  end

  test "authenticates with secure password digest" do
    manager = create_manager(email: "LAIA.RIERA@EXAMPLE.TEST", password: "secret")

    assert_equal "laia.riera@example.test", manager.email
    assert_predicate manager.password_digest, :present?
    assert manager.authenticate_password("secret")
    assert_not manager.authenticate_password("bad")
    assert_equal manager, Manager.find_active_by_email(" laia.riera@example.test ")
  end

  test "generates setup and reset tokens with separate expirations" do
    manager = create_manager(password: nil)
    setup_token = manager.password_setup_token

    travel Manager::PASSWORD_SETUP_TOKEN_TTL - 1.day
    assert_equal manager, Manager.find_by_password_setup_token(setup_token)

    manager.update!(password: "secret123")
    assert_nil Manager.find_by_password_setup_token(setup_token)

    reset_token = manager.password_reset_token
    assert_equal 1.hour, manager.password_reset_token_expires_in

    travel Manager::PASSWORD_RESET_TOKEN_TTL + 1.second
    assert_nil Manager.find_by_password_reset_token(reset_token)
  end

  test "stores last request access in settings" do
    manager = create_manager(settings: { "theme" => "light" })
    accessed_at = Time.zone.local(2026, 7, 26, 11, 45)

    manager.record_request_access!(at: accessed_at)

    manager.reload
    assert_equal "light", manager.settings["theme"]
    assert_equal accessed_at.to_i, manager.last_request_at.to_i
  end

  test "does not update last request access inside grace period" do
    manager = create_manager
    first_access_at = Time.zone.local(2026, 7, 26, 11, 45)
    second_access_at = first_access_at + 9.minutes

    assert manager.record_request_access!(at: first_access_at)
    assert_not manager.record_request_access!(at: second_access_at)

    assert_equal first_access_at.to_i, manager.reload.last_request_at.to_i
  end

  test "updates last request access after grace period" do
    manager = create_manager
    first_access_at = Time.zone.local(2026, 7, 26, 11, 45)
    second_access_at = first_access_at + 10.minutes

    manager.record_request_access!(at: first_access_at)
    assert manager.record_request_access!(at: second_access_at)

    assert_equal second_access_at.to_i, manager.reload.last_request_at.to_i
  end

  test "ignores invalid last request access timestamps" do
    manager = create_manager(settings: { Manager::LAST_REQUEST_AT_SETTING_KEY => "bad" })

    assert_nil manager.last_request_at
  end
end
