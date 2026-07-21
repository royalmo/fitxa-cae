class SwipeCorrection < ApplicationRecord
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true

  belongs_to :employee
  belongs_to :requester, polymorphic: true
  belongs_to :validator, class_name: "Manager", optional: true, inverse_of: :validated_swipe_corrections

  validates :status, :day, presence: true
  validate :single_pending_correction_per_day, if: :pending?

  def self.employee_request_day_range(reference_date: Time.zone.today)
    reference_date.prev_month.beginning_of_month..reference_date
  end

  def self.employee_request_day_allowed?(day, reference_date: Time.zone.today)
    day.present? && employee_request_day_range(reference_date: reference_date).cover?(day)
  end

  private

  def single_pending_correction_per_day
    return if employee_id.blank? || day.blank?

    duplicate = self.class.pending.where(employee_id: employee_id, day: day)
    duplicate = duplicate.where.not(id: id) if persisted?

    errors.add(:day, :pending_taken) if duplicate.exists?
  end
end
