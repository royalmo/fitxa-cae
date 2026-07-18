class ErrorReportSubscriber
  MAX_BACKTRACE_LINES = 40
  MAX_CONTEXT_VALUE_LENGTH = 500

  def report(error, handled:, severity:, context:, source:)
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
