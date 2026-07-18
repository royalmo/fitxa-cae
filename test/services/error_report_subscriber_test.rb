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
      context: { password: "secret", delivery_method: "email" },
      source: "fitxa_cae"
    )

    assert_equal "\"email\"", payload[:context]["delivery_method"]
    assert_match "[FILTERED]", payload[:context]["password"]
  ensure
    singleton.define_method(:report, original_method) if original_method
  end
end
