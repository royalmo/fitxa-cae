class DailyStatistic < ApplicationRecord
  scope :chronological, -> { order(:snapshot_at) }
  scope :recent, ->(limit) { chronological.where(snapshot_at: limit.days.ago.to_date..) }

  validates :snapshot_at, presence: true, uniqueness: true
  validates :active_user_count, :pending_correction_count, :people_worked,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
