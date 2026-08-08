class EmploymentPeriod < ApplicationRecord
  belongs_to :employee

  scope :chronological, -> { order(:started_at, :id) }
  scope :open, -> { where(ended_at: nil) }
  scope :overlapping, ->(range) {
    where("started_at < ? AND (ended_at IS NULL OR ended_at > ?)", range.end, range.begin)
  }

  validates :started_at, presence: true
  validate :ended_at_after_started_at

  def open?
    ended_at.nil?
  end

  private

  def ended_at_after_started_at
    return if started_at.blank? || ended_at.blank?
    return if ended_at > started_at

    errors.add(:ended_at, :after_started_at)
  end
end
