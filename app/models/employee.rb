require "digest"

class Employee < ApplicationRecord
  NATIONAL_ID_LETTERS = "TRWAGMYFPDXBNJZSQVHLCKE"
  LOGIN_CODE_TTL = 30.minutes
  LOGIN_CODE_COOLDOWN = 1.minute
  LOGIN_CODE_LIMIT = 5
  LOGIN_CODE_LIMIT_WINDOW = 1.hour
  LOGIN_CODE_RANDOM_DIGITS = 5
  LOGIN_CODE_LENGTH = LOGIN_CODE_RANDOM_DIGITS + 1
  LOGIN_CODE_CHECKSUM = "weighted_mod10_sum"
  LOGIN_CODE_CHECKSUM_WEIGHTS = [ 2, 1, 2, 1, 2, 1 ].freeze

  before_validation :normalize_national_id_attribute

  has_secure_password validations: false

  has_one :manager, dependent: :nullify
  has_many :swipes
  has_many :swipe_corrections, dependent: :destroy
  has_many :requested_swipe_corrections, as: :requester, class_name: "SwipeCorrection"
  has_many :authored_audit_actions, as: :author, class_name: "AuditAction"
  has_many :received_audit_actions, as: :recipient, class_name: "AuditAction"
  has_and_belongs_to_many :tags

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  validates :first_name, :national_id, presence: true
  validate :national_id_has_valid_spanish_check_letter
  validates :active, inclusion: { in: [ true, false ] }

  def self.normalize_national_id(national_id)
    national_id.to_s.strip.upcase.presence
  end

  def self.find_active_by_national_id(national_id)
    where(active: true).find_by(national_id: normalize_national_id(national_id))
  end

  def self.valid_national_id?(national_id)
    normalized_national_id = normalize_national_id(national_id)

    return false unless normalized_national_id

    expected_national_id_letter(normalized_national_id) == normalized_national_id.last
  end

  def self.generate_login_code
    random_digits = SecureRandom.random_number(10**LOGIN_CODE_RANDOM_DIGITS).to_s.rjust(LOGIN_CODE_RANDOM_DIGITS, "0")

    "#{random_digits}#{login_code_check_digit(random_digits)}"
  end

  def self.valid_login_code_checksum?(code)
    normalized_code = normalize_login_code(code)

    return false unless normalized_code&.match?(/\A\d{#{LOGIN_CODE_LENGTH}}\z/)

    weighted_login_code_sum(normalized_code) % 10 == 0
  end

  def self.normalize_login_code(code)
    code.to_s.gsub(/\D/, "").presence
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def password_login_enabled?
    password_digest.present?
  end

  def latest_swipe(at: Time.current, on: nil)
    scope = swipes.kept.where(swipe_at: ..at)
    scope = scope.for_day(on) if on

    scope.order(swipe_at: :desc, id: :desc).first
  end

  def open_entry_swipe(at: Time.current)
    swipe = latest_swipe(at: at, on: at.in_time_zone.to_date)
    swipe if swipe&.entry?
  end

  def clocked_in?(at: Time.current)
    open_entry_swipe(at: at).present?
  end

  def can_receive_login_code?(delivery_method)
    case delivery_method.to_s
    when "sms"
      phone.present?
    when "email"
      email.present?
    else
      false
    end
  end

  def login_code_rate_limited?(now: Time.current)
    recent_login_code_requests(now: now).count >= LOGIN_CODE_LIMIT || login_code_cooldown_active?(now: now)
  end

  def generate_login_code!(delivery_method:, expires_at: LOGIN_CODE_TTL.from_now, requested_at: Time.current)
    code = self.class.generate_login_code
    request_history = recent_login_code_requests(now: requested_at).append(requested_at.iso8601)
    next_settings = settings.merge(
      "login_code" => {
        "digest" => Digest::SHA256.hexdigest(code),
        "delivery_method" => delivery_method.to_s,
        "expires_at" => expires_at.iso8601,
        "checksum" => LOGIN_CODE_CHECKSUM
      },
      "login_code_request_history" => request_history
    )

    update!(settings: next_settings)
    code
  end

  def authenticate_login_code(code)
    login_code = settings["login_code"]
    submitted_code = self.class.normalize_login_code(code)

    return false unless login_code.present? && submitted_code.present?
    return false if login_code_expired?(login_code)
    return false if login_code["checksum"] == LOGIN_CODE_CHECKSUM && !self.class.valid_login_code_checksum?(submitted_code)

    expected_digest = login_code["digest"].to_s
    actual_digest = Digest::SHA256.hexdigest(submitted_code)

    ActiveSupport::SecurityUtils.secure_compare(actual_digest, expected_digest)
  rescue ArgumentError
    false
  end

  def clear_login_code!
    update!(settings: settings.except("login_code"))
  end

  private

  def normalize_national_id_attribute
    self.national_id = self.class.normalize_national_id(national_id)
  end

  def national_id_has_valid_spanish_check_letter
    return if national_id.blank?
    return if self.class.valid_national_id?(national_id)

    errors.add(:national_id, :invalid)
  end

  def self.expected_national_id_letter(national_id)
    number = national_id_number(national_id)
    NATIONAL_ID_LETTERS[number % NATIONAL_ID_LETTERS.length] if number
  end
  private_class_method :expected_national_id_letter

  def self.national_id_number(national_id)
    case national_id
    when /\A\d{8}[A-Z]\z/
      national_id.first(8).to_i
    when /\A[XYZ]\d{7}[A-Z]\z/
      national_id.tr("XYZ", "012").first(8).to_i
    end
  end
  private_class_method :national_id_number

  def self.login_code_check_digit(code)
    sum = weighted_login_code_sum(code)

    (10 - (sum % 10)) % 10
  end
  private_class_method :login_code_check_digit

  def self.weighted_login_code_sum(code)
    code.chars.each_with_index.sum do |digit, index|
      digit.to_i * LOGIN_CODE_CHECKSUM_WEIGHTS[index]
    end
  end
  private_class_method :weighted_login_code_sum

  def login_code_expired?(login_code)
    expires_at = Time.zone.parse(login_code["expires_at"].to_s)

    expires_at.blank? || expires_at.past?
  end

  def login_code_cooldown_active?(now:)
    last_requested_at = recent_login_code_requests(now: now).filter_map { |timestamp| Time.zone.parse(timestamp.to_s) }.max

    last_requested_at.present? && last_requested_at > now - LOGIN_CODE_COOLDOWN
  end

  def recent_login_code_requests(now:)
    Array(settings["login_code_request_history"]).select do |timestamp|
      requested_at = Time.zone.parse(timestamp.to_s)

      requested_at.present? && requested_at > now - LOGIN_CODE_LIMIT_WINDOW
    rescue ArgumentError
      false
    end
  end
end
