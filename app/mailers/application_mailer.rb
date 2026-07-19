class ApplicationMailer < ActionMailer::Base
  self.delivery_job = ApplicationMailDeliveryJob

  default from: "from@example.com"
  layout "mailer"
end
