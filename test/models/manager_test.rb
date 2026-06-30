require "test_helper"

class ManagerTest < ActiveSupport::TestCase
  test "is valid without an employee and defaults to active" do
    manager = Manager.create!(first_name: "Laia", last_name: "Riera")

    assert_predicate manager, :active?
    assert_nil manager.employee
  end

  test "can be linked to one employee" do
    employee = create_employee
    manager = create_manager(employee: employee)

    assert_equal employee, manager.employee
    assert_equal manager, employee.manager
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
end
