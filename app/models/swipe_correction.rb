class SwipeCorrection < ApplicationRecord
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true

  belongs_to :employee
  belongs_to :requester, polymorphic: true
  belongs_to :validator, class_name: "Manager", optional: true, inverse_of: :validated_swipe_corrections

  validates :status, :day, presence: true

  def self.employee_request_day_range(reference_date: Time.zone.today)
    reference_date.prev_month.beginning_of_month..reference_date
  end

  def self.employee_request_day_allowed?(day, reference_date: Time.zone.today)
    day.present? && employee_request_day_range(reference_date: reference_date).cover?(day)
  end
end
