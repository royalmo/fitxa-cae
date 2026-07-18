module ErrorNotifier
  module_function

  def notify(error, data: {})
    Rails.logger.error("#{error.class}: #{error.message}")

    Rails.error.report(
      error,
      handled: true,
      severity: :error,
      context: data,
      source: "fitxa_cae"
    )
    true
  rescue StandardError => notification_error
    Rails.logger.error(
      "Error reporting failed: #{notification_error.class}: #{notification_error.message}"
    )
    false
  end
end
