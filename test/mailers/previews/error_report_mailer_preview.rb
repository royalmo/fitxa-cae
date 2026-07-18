# Preview all emails at http://localhost:3000/rails/mailers/error_report_mailer
class ErrorReportMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/error_report_mailer/report
  def report
    ErrorReportMailer.report(
      environment: Rails.env.to_s.titleize,
      error_class: "LoginCodeDeliveryConfig::ConfigurationError",
      message: "SMTP is not configured",
      severity: "error",
      handled: true,
      source: "fitxa_cae",
      context: { "delivery_method" => "\"email\"" },
      backtrace: [ "app/controllers/employee/sessions_controller.rb:152" ]
    )
  end
end
