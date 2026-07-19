class ApplicationJob < ActiveJob::Base
  rescue_from(StandardError) do |error|
    report_job_error(error)
    raise error
  end

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  def report_job_error(error, data: {})
    return if @job_error_reported

    @job_error_reported = true
    ErrorNotifier.notify(
      error,
      data: {
        context: "active_job",
        job_class: self.class.name,
        job_id: job_id,
        queue_name: queue_name,
        executions: executions
      }.compact.merge(data)
    )
  end
end
