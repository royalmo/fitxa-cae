class ApplicationMailer < ActionMailer::Base
  self.delivery_job = ApplicationMailDeliveryJob

  default from: -> { Rails.configuration.x.mailer_from_email },
    reply_to: -> { Rails.configuration.x.mailer_reply_to_email }
  layout "mailer"

  helper_method :mailer_app_url, :mailer_logo_url

  private

  def mailer_app_url
    root_url
  end

  def mailer_logo_url
    attachments.inline["cae_logo_trimmed.png"] ||= Rails.root.join("app/assets/images/cae_logo_trimmed.png").read
    attachments["cae_logo_trimmed.png"].url
  end
end
