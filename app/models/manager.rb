class Manager < ApplicationRecord
  before_validation :normalize_email_attribute

  has_secure_password validations: false

  scope :active, -> { where(active: true) }

  belongs_to :employee, optional: true

  has_many :validated_swipe_corrections,
    class_name: "SwipeCorrection",
    foreign_key: :validator_id,
    inverse_of: :validator
  has_many :requested_swipe_corrections, as: :requester, class_name: "SwipeCorrection"
  has_many :authored_audit_actions, as: :author, class_name: "AuditAction"
  has_many :received_audit_actions, as: :recipient, class_name: "AuditAction"

  validates :active, inclusion: { in: [ true, false ] }

  def self.normalize_email(email)
    email.to_s.strip.downcase.presence
  end

  def self.find_active_by_email(email)
    normalized_email = normalize_email(email)

    active.where("LOWER(email) = ?", normalized_email).first if normalized_email
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def authenticate_password(password)
    password.present? && authenticate(password).present?
  end

  private

  def normalize_email_attribute
    self.email = self.class.normalize_email(email)
  end
end
