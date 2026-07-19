class ApplicationMailDeliveryJob < ActionMailer::MailDeliveryJob
  rescue_from(StandardError) do |error|
    ErrorNotifier.notify(
      error,
      data: mail_delivery_error_context
    )
    raise error
  end

  private

  def mail_delivery_error_context
    mailer, action, delivery_method = arguments

    {
      context: "mail_delivery",
      mailer: mailer,
      action: action,
      delivery_method: delivery_method,
      job_id: job_id,
      queue_name: queue_name,
      executions: executions
    }.compact
  end
end
