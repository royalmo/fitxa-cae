class Employee < ApplicationRecord
  NATIONAL_ID_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE"

  before_validation :normalize_national_id

  has_one :manager, dependent: :nullify
  has_many :swipes
  has_many :swipe_corrections, dependent: :destroy
  has_many :requested_swipe_corrections, as: :requester, class_name: "SwipeCorrection"
  has_many :authored_audit_actions, as: :author, class_name: "AuditAction"
  has_many :received_audit_actions, as: :recipient, class_name: "AuditAction"
  has_and_belongs_to_many :tags

  validates :first_name, :national_id, presence: true
  validate :national_id_has_valid_spanish_check_letter
  validates :active, inclusion: { in: [ true, false ] }

  private

  def normalize_national_id
    self.national_id = national_id.to_s.strip.upcase.presence
  end

  def national_id_has_valid_spanish_check_letter
    return if national_id.blank?

    number = national_id_number
    expected_letter = NATIONAL_ID_LETTERS[number % NATIONAL_ID_LETTERS.length] if number

    return if expected_letter == national_id.last

    errors.add(:national_id, :invalid)
  end

  def national_id_number
    case national_id
    when /\A\d{8}[A-Z]\z/
      national_id.first(8).to_i
    when /\A[XYZ]\d{7}[A-Z]\z/
      national_id.tr("XYZ", "012").first(8).to_i
    end
  end
end
