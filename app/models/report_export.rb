class ReportExport < ApplicationRecord
  KINDS = %w[person_pdf tag_zip company_zip monthly_summary_pdf].freeze
  STATUSES = %w[queued running completed failed expired].freeze
  DEFAULT_EXPIRATION = 24.hours

  enum :status, STATUSES.index_with(&:itself), validate: true

  belongs_to :manager
  has_one_attached :artifact

  validates :kind, inclusion: { in: KINDS }
  validates :parameters, presence: true
  validates :progress, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  before_validation :set_default_expiration, on: :create

  scope :expired_for_cleanup, ->(now = Time.current) { where(expires_at: ..now).where.not(status: :expired) }

  def downloadable?
    completed? && artifact.attached? && !past_expiration?
  end

  def past_expiration?
    expires_at.present? && expires_at <= Time.current
  end

  def mark_running!(progress: 10)
    update!(status: :running, progress: progress)
  end

  def mark_completed!(filename:, content_type:)
    update!(
      status: :completed,
      progress: 100,
      filename: filename,
      content_type: content_type,
      completed_at: Time.current,
      error_message: nil
    )
  end

  def mark_failed!(message)
    update!(
      status: :failed,
      failed_at: Time.current,
      error_message: message.to_s.presence || I18n.t("admin.report_exports.errors.generic")
    )
  end

  def mark_expired!
    artifact.purge_later if artifact.attached?
    update!(status: :expired, progress: 100)
  end

  private

  def set_default_expiration
    self.expires_at ||= DEFAULT_EXPIRATION.from_now
  end
end
