class ApplicationMailer < ActionMailer::Base
  self.delivery_job = ApplicationMailDeliveryJob

  default from: -> { Rails.configuration.x.mailer_from_email }
  layout "mailer"
end
