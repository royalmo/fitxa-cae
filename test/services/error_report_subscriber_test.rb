require "test_helper"

class ErrorReportSubscriberTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "queues an error report email" do
    assert_enqueued_emails 1 do
      ErrorReportSubscriber.new.report(
        StandardError.new("Cannot send login code"),
        handled: true,
        severity: :error,
        context: { delivery_method: "email" },
        source: "fitxa_cae"
      )
    end
  end

  test "filters sensitive context values" do
    singleton = class << ErrorReportMailer
      self
    end
    original_method = ErrorReportMailer.method(:report)
    payload = nil

    singleton.define_method(:report) do |report_payload|
      payload = report_payload
      Struct.new(:payload) do
        def deliver_later
        end
      end.new(report_payload)
    end

    ErrorReportSubscriber.new.report(
      StandardError.new("Cannot send login code"),
      handled: true,
      severity: :error,
      context: {
        password: "secret",
        national_id: "12345678Z",
        phone: "+34 600 111 222",
        code_digits: %w[1 2 3 4 5 6],
        delivery_method: "sms"
      },
      source: "fitxa_cae"
    )

    assert_equal "\"sms\"", payload[:context]["delivery_method"]
    assert_match "[FILTERED]", payload[:context]["password"]
    assert_match "[FILTERED]", payload[:context]["national_id"]
    assert_match "[FILTERED]", payload[:context]["phone"]
    assert_match "[FILTERED]", payload[:context]["code_digits"]
  ensure
    singleton.define_method(:report, original_method) if original_method
  end
end
