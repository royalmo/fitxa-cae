require "test_helper"

class CaptureDailyStatisticsJobTest < ActiveJob::TestCase
  test "captures yesterday counts and updates an existing snapshot" do
    active_employee = nil
    inactive_employee = nil

    travel_to Time.zone.local(2026, 8, 2, 8, 0) do
      active_employee = create_employee(national_id: valid_dni(43_000_001), active: true)
      inactive_employee = create_employee(national_id: valid_dni(43_000_002), active: true)
    end

    travel_to Time.zone.local(2026, 8, 4, 1, 15) do
      ignored_employee = create_employee(national_id: valid_dni(43_000_003), active: true)
      inactive_employee.update!(active: false)
      active_employee.swipe_corrections.create!(requester: active_employee, status: :pending, day: Date.yesterday)
      active_employee.swipe_corrections.create!(requester: active_employee, status: :approved, day: 2.days.ago.to_date)
      active_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 3, 8, 0))
      inactive_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 3, 9, 0))
      ignored_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 3, 10, 0), removed: true)
      ignored_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 4, 8, 0))
      DailyStatistic.create!(
        snapshot_at: Date.yesterday,
        active_user_count: 99,
        pending_correction_count: 99,
        people_worked: 99
      )

      CaptureDailyStatisticsJob.perform_now
    end

    daily_statistic = DailyStatistic.find_by!(snapshot_at: Date.new(2026, 8, 3))
    assert_equal 2, daily_statistic.active_user_count
    assert_equal 1, daily_statistic.pending_correction_count
    assert_equal 2, daily_statistic.people_worked
    assert_equal 1, DailyStatistic.where(snapshot_at: Date.new(2026, 8, 3)).count
  end
end
