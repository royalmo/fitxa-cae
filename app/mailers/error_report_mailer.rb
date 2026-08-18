class ErrorReportMailer < ApplicationMailer
  self.delivery_job = ActionMailer::MailDeliveryJob
  layout "plain_mailer"

  DEFAULT_RECIPIENTS = "eric@ericroy.net"

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
    ENV.fetch("ERROR_NOTIFICATION_SENDER", Rails.configuration.x.mailer_from_email)
  end

  def error_subject
    message = @error_report.fetch(:message).to_s.tr("\n", " ").truncate(80)
    "[#{app_name} #{@error_report.fetch(:environment)} ERROR] #{@error_report.fetch(:error_class)}: #{message}"
  end
end
