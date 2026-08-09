class HumanResourcesContactMailer < ApplicationMailer
  def contact_request(employee, subject:, body:)
    @employee = employee
    @subject = subject.to_s
    @body = body.to_s

    mail(
      to: Rails.configuration.x.human_resources_email,
      reply_to: @employee.email.presence || Rails.configuration.x.mailer_reply_to_email,
      subject: t(".subject", subject: @subject)
    )
  end
end
