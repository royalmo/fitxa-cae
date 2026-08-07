require Rails.root.join("app/mailers/development_console_mail_delivery")

ActionMailer::Base.add_delivery_method(:console, DevelopmentConsoleMailDelivery)
