class SwipeCorrection < ApplicationRecord
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true

  belongs_to :employee
  belongs_to :requester, polymorphic: true
  belongs_to :validator, class_name: "Manager", optional: true, inverse_of: :validated_swipe_corrections

  validates :status, :day, presence: true
end
