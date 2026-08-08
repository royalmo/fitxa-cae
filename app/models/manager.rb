class Manager < ApplicationRecord
  LAST_REQUEST_AT_SETTING_KEY = "last_request_at"
  LAST_REQUEST_ACCESS_GRACE_PERIOD = 10.minutes
  PASSWORD_RESET_TOKEN_TTL = 1.hour
  PASSWORD_SETUP_TOKEN_TTL = 1.month

  before_validation :normalize_email_attribute

  has_secure_password validations: false, reset_token: { expires_in: PASSWORD_RESET_TOKEN_TTL }
  generates_token_for :password_setup, expires_in: PASSWORD_SETUP_TOKEN_TTL do
    password_salt&.last(10)
  end

  scope :active, -> { where(active: true) }

  belongs_to :employee, optional: true

  has_many :validated_swipe_corrections,
    class_name: "SwipeCorrection",
    foreign_key: :validator_id,
    inverse_of: :validator
  has_many :requested_swipe_corrections, as: :requester, class_name: "SwipeCorrection"
  has_many :authored_audit_actions, as: :author, class_name: "AuditAction"
  has_many :received_audit_actions, as: :recipient, class_name: "AuditAction"
  has_many :report_exports, dependent: :destroy
  has_many :employee_bulk_action_runs, dependent: :destroy

  validates :active, inclusion: { in: [ true, false ] }
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :employee_id, uniqueness: { allow_nil: true }

  def self.normalize_email(email)
    email.to_s.strip.downcase.presence
  end

  def self.find_active_by_email(email)
    normalized_email = normalize_email(email)

    active.where("LOWER(email) = ?", normalized_email).first if normalized_email
  end

  def self.find_by_password_setup_token(token)
    find_by_token_for(:password_setup, token)
  end

  def password_setup_token
    generate_token_for(:password_setup)
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def authenticate_password(password)
    password.present? && authenticate(password).present?
  end

  def last_request_at
    timestamp = settings&.[](LAST_REQUEST_AT_SETTING_KEY)
    Time.zone.parse(timestamp.to_s) if timestamp.present?
  rescue ArgumentError
    nil
  end

  def record_request_access!(at: Time.current)
    return false if last_request_at.present? && last_request_at > at - LAST_REQUEST_ACCESS_GRACE_PERIOD

    update_columns(settings: settings.to_h.merge(LAST_REQUEST_AT_SETTING_KEY => at.iso8601))
  end

  private

  def normalize_email_attribute
    self.email = self.class.normalize_email(email)
  end
end
