require "test_helper"

class SwipeCorrectionTest < ActiveSupport::TestCase
  test "defaults to pending and allows missing validator" do
    employee = create_employee
    correction = SwipeCorrection.create!(employee: employee, requester: employee, day: Date.new(2026, 6, 30))

    assert_predicate correction, :pending?
    assert_nil correction.validator
  end

  test "accepts approved and rejected statuses with validators" do
    employee = create_employee
    manager = create_manager
    approved = SwipeCorrection.new(
      employee: employee,
      requester: employee,
      validator: manager,
      status: "approved",
      day: Date.new(2026, 6, 29)
    )
    rejected = SwipeCorrection.new(
      employee: employee,
      requester: manager,
      validator: manager,
      status: "rejected",
      day: Date.new(2026, 6, 28)
    )

    assert_predicate approved, :valid?
    assert_predicate rejected, :valid?
  end

  test "requires employee requester day and valid status" do
    correction = SwipeCorrection.new(status: "unknown")

    assert_not correction.valid?
    assert_model_error correction, :employee, :blank
    assert_model_error correction, :requester, :blank
    assert_model_error correction, :day, :blank
    assert_model_error correction, :status, :inclusion
  end

  test "stores correction details as structured json" do
    employee = create_employee
    swipe = Swipe.create!(employee: employee, swipe_at: Time.zone.local(2026, 6, 30, 8), kind: "entry")
    details = {
      "invalidated_swipe_ids" => [ swipe.id ],
      "requested_swipes" => [
        { "kind" => "entry", "hour" => "08:05:00" },
        { "kind" => "exit", "hour" => "17:00:00" }
      ]
    }

    correction = SwipeCorrection.create!(
      employee: employee,
      requester: employee,
      day: Date.new(2026, 6, 30),
      details: details
    )

    assert_equal details, correction.reload.details
  end

  test "only allows one pending correction per employee and day" do
    employee = create_employee
    SwipeCorrection.create!(employee: employee, requester: employee, day: Date.new(2026, 6, 30), status: :pending)

    duplicate = SwipeCorrection.new(employee: employee, requester: employee, day: Date.new(2026, 6, 30), status: :pending)
    reviewed = SwipeCorrection.new(employee: employee, requester: employee, day: Date.new(2026, 6, 30), status: :approved)

    assert_not duplicate.valid?
    assert_model_error duplicate, :day, :pending_taken
    assert_predicate reviewed, :valid?
  end
end
