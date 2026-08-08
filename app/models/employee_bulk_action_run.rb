class EmployeeBulkActionRun < ApplicationRecord
  KINDS = %w[activation tags import].freeze
  STATUSES = %w[queued running completed failed].freeze

  enum :status, STATUSES.index_with(&:itself), validate: true

  belongs_to :manager

  validates :kind, inclusion: { in: KINDS }
  validates :parameters, presence: true
  validates :progress, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def terminal?
    completed? || failed?
  end

  def mark_running!(progress: 8)
    update!(status: :running, progress: progress)
  end

  def mark_completed!(message)
    update!(
      status: :completed,
      progress: 100,
      completed_at: Time.current,
      result_message: message,
      error_message: nil
    )
  end

  def mark_failed!(message)
    update!(
      status: :failed,
      progress: 100,
      failed_at: Time.current,
      error_message: message.to_s.presence || I18n.t("admin.employee_bulk_action_runs.errors.generic")
    )
  end
end
