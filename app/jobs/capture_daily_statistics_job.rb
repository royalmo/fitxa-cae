class CaptureDailyStatisticsJob < ApplicationJob
  queue_as :default

  def perform(snapshot_at = Time.zone.yesterday)
    snapshot_at = snapshot_date(snapshot_at)

    DailyStatistic.find_or_initialize_by(snapshot_at: snapshot_at).tap do |daily_statistic|
      daily_statistic.update!(
        active_user_count: active_user_count(snapshot_at),
        pending_correction_count: SwipeCorrection.pending.count,
        people_worked: people_worked_count(snapshot_at)
      )
    end
  end

  private

  def snapshot_date(value)
    value.respond_to?(:to_date) ? value.to_date : Date.iso8601(value.to_s)
  end

  def people_worked_count(snapshot_at)
    Swipe.kept
      .where(swipe_at: snapshot_at.all_day)
      .distinct
      .count(:employee_id)
  end

  def active_user_count(snapshot_at)
    Employee.active_during(snapshot_at.beginning_of_day...snapshot_at.next_day.beginning_of_day).count
  end
end
