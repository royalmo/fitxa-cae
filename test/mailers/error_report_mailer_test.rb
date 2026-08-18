require "test_helper"

class ErrorReportMailerTest < ActionMailer::TestCase
  test "report emails the configured error recipient" do
    original = ENV["ERROR_NOTIFICATION_SENDER"]
    ENV["ERROR_NOTIFICATION_SENDER"] = "random-shit@example.com"

    mail = ErrorReportMailer.report(sample_error_report)

    assert_equal "[FitxaCAE Test ERROR] StandardError: Cannot send login code", mail.subject
    assert_equal [ "eric@ericroy.net" ], mail.to
    assert_equal [ "random-shit@example.com" ], mail.from
    assert_equal [ "rrhh@cae.cat" ], mail.reply_to
    assert_match "Cannot send login code", mail.body.encoded
    assert_match "delivery_method", mail.body.encoded
  ensure
    ENV["ERROR_NOTIFICATION_SENDER"] = original
  end

  private

  def sample_error_report
    {
      environment: "Test",
      error_class: "StandardError",
      message: "Cannot send login code",
      severity: "error",
      handled: true,
      source: "fitxa_cae",
      context: { "delivery_method" => "\"email\"" },
      backtrace: [ "app/controllers/employee/sessions_controller.rb:1" ]
    }
  end
end
