class ErrorReportSubscriber
  MAX_BACKTRACE_LINES = 40
  MAX_CONTEXT_VALUE_LENGTH = 500

  def report(error, handled:, severity:, context:, source:)
    return false if error_report_delivery_failure?(context, source)

    ErrorReportMailer.report(
      report_payload(error, handled:, severity:, context:, source:)
    ).deliver_later
  rescue StandardError => notification_error
    Rails.logger.error(
      "Error report delivery failed: #{notification_error.class}: #{notification_error.message}"
    )
    false
  end

  private

  def error_report_delivery_failure?(context, source)
    return false unless source.to_s.include?("solid_queue")

    job = context.to_h[:job] || context.to_h["job"]
    return false unless job

    if job.respond_to?(:arguments)
      job.arguments.first.to_s == "ErrorReportMailer"
    else
      job.to_s.include?("ActionMailer::MailDeliveryJob") && job.to_s.include?("ErrorReportMailer")
    end
  end

  def report_payload(error, handled:, severity:, context:, source:)
    {
      environment: Rails.env.to_s.titleize,
      error_class: error.class.name,
      message: error.message.to_s,
      handled: handled,
      severity: severity.to_s,
      source: source.to_s,
      context: filtered_context(context),
      backtrace: Rails.backtrace_cleaner.clean(error.backtrace || []).first(MAX_BACKTRACE_LINES)
    }
  end

  def filtered_context(context)
    filter_parameters(context.to_h).transform_keys(&:to_s).transform_values do |value|
      value.inspect.truncate(MAX_CONTEXT_VALUE_LENGTH)
    end
  end

  def filter_parameters(context)
    ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter(context)
  end
end
