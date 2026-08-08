require "test_helper"

class EmploymentPeriodTest < ActiveSupport::TestCase
  test "requires a start and an end after the start" do
    employee = create_employee(active: false)
    period = employee.employment_periods.build

    assert_not period.valid?
    assert_model_error period, :started_at, :blank

    period.started_at = Time.zone.local(2026, 7, 1, 8, 0)
    period.ended_at = period.started_at

    assert_not period.valid?
    assert_model_error period, :ended_at, :after_started_at

    period.ended_at = period.started_at + 1.second

    assert_predicate period, :valid?
  end

  test "finds periods overlapping a half open time range" do
    range = Time.zone.local(2026, 7, 1)...Time.zone.local(2026, 8, 1)
    employee = create_employee(active: false)
    ending_at_start = employee.employment_periods.create!(
      started_at: Time.zone.local(2026, 6, 1),
      ended_at: range.begin
    )
    spanning_start = employee.employment_periods.create!(
      started_at: Time.zone.local(2026, 6, 20),
      ended_at: Time.zone.local(2026, 7, 10)
    )
    contained = employee.employment_periods.create!(
      started_at: Time.zone.local(2026, 7, 5),
      ended_at: Time.zone.local(2026, 7, 20)
    )
    open_period = employee.employment_periods.create!(started_at: Time.zone.local(2026, 7, 25))
    starting_at_end = employee.employment_periods.create!(
      started_at: range.end,
      ended_at: Time.zone.local(2026, 8, 2)
    )

    overlapping_ids = EmploymentPeriod.overlapping(range).pluck(:id)

    assert_includes overlapping_ids, spanning_start.id
    assert_includes overlapping_ids, contained.id
    assert_includes overlapping_ids, open_period.id
    assert_not_includes overlapping_ids, ending_at_start.id
    assert_not_includes overlapping_ids, starting_at_end.id
  end
end
