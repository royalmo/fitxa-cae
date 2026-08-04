require "test_helper"

class DailyStatisticTest < ActiveSupport::TestCase
  test "requires a unique snapshot day and non negative integer counts" do
    DailyStatistic.create!(
      snapshot_at: Date.new(2026, 8, 3),
      active_user_count: 3,
      pending_correction_count: 2,
      people_worked: 1
    )
    daily_statistic = DailyStatistic.new(
      snapshot_at: Date.new(2026, 8, 3),
      active_user_count: -1,
      pending_correction_count: 1.5,
      people_worked: nil
    )

    assert_not daily_statistic.valid?
    assert_model_error daily_statistic, :snapshot_at, :taken
    assert_model_error daily_statistic, :active_user_count, :greater_than_or_equal_to
    assert_model_error daily_statistic, :pending_correction_count, :not_an_integer
    assert_model_error daily_statistic, :people_worked, :not_a_number
  end
end
