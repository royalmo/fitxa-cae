class ErrorReportMailer < ApplicationMailer
  self.delivery_job = ActionMailer::MailDeliveryJob

  DEFAULT_RECIPIENTS = "eric@ericroy.net"
  DEFAULT_SENDER = "FitxaCAE Errors <errors@fitxacae.invalid>"

  def report(error_report)
    @error_report = error_report

    mail(
      to: error_recipients,
      from: error_sender,
      subject: error_subject
    )
  end

  private

  def error_recipients
    ENV.fetch("ERROR_NOTIFICATION_RECIPIENTS", DEFAULT_RECIPIENTS).split(",").map(&:strip)
  end

  def error_sender
    ENV.fetch("ERROR_NOTIFICATION_SENDER", DEFAULT_SENDER)
  end

  def error_subject
    message = @error_report.fetch(:message).to_s.tr("\n", " ").truncate(80)
    "[FitxaCAE #{@error_report.fetch(:environment)} ERROR] #{@error_report.fetch(:error_class)}: #{message}"
  end
end
