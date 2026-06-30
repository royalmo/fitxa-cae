class Manager < ApplicationRecord
  belongs_to :employee, optional: true

  has_many :validated_swipe_corrections,
    class_name: "SwipeCorrection",
    foreign_key: :validator_id,
    inverse_of: :validator
  has_many :requested_swipe_corrections, as: :requester, class_name: "SwipeCorrection"
  has_many :authored_audit_actions, as: :author, class_name: "AuditAction"
  has_many :received_audit_actions, as: :recipient, class_name: "AuditAction"

  validates :active, inclusion: { in: [ true, false ] }
end
