Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorReportSubscriber.new) unless Rails.env.test?
end
