require "test_helper"

class SwipeTest < ActiveSupport::TestCase
  test "is valid for entry and exit kinds" do
    employee = create_employee
    entry = Swipe.new(employee: employee, swipe_at: Time.zone.local(2026, 6, 30, 8), kind: "entry")
    exit_swipe = Swipe.new(employee: employee, swipe_at: Time.zone.local(2026, 6, 30, 17), kind: "exit")

    assert_predicate entry, :valid?
    assert_predicate exit_swipe, :valid?
  end

  test "defaults removed and forged to false" do
    swipe = Swipe.create!(employee: create_employee, swipe_at: Time.zone.local(2026, 6, 30, 8), kind: "entry")

    assert_not swipe.removed?
    assert_not swipe.forged?
  end

  test "requires employee swipe time and valid kind" do
    swipe = Swipe.new(kind: "break")

    assert_not swipe.valid?
    assert_model_error swipe, :employee, :blank
    assert_model_error swipe, :swipe_at, :blank
    assert_model_error swipe, :kind, :inclusion
  end

  test "requires boolean removed and forged values" do
    swipe = Swipe.new(
      employee: create_employee,
      swipe_at: Time.zone.local(2026, 6, 30, 8),
      kind: "entry",
      removed: nil,
      forged: nil
    )

    assert_not swipe.valid?
    assert_model_error swipe, :removed, :inclusion
    assert_model_error swipe, :forged, :inclusion
  end
end
