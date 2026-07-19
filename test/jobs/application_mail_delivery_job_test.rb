require "test_helper"

class ApplicationMailDeliveryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  class BrokenMailer < ApplicationMailer
    def broken
      raise StandardError, "Cannot deliver mail"
    end
  end

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "reports mail delivery failures" do
    with_error_notifications do |notifications|
      BrokenMailer.broken.deliver_later

      assert_raises(StandardError) do
        perform_enqueued_jobs(only: ApplicationMailDeliveryJob)
      end

      assert_equal 1, notifications.size
      assert_equal "mail_delivery", notifications.first[:data][:context]
      assert_match "BrokenMailer", notifications.first[:data][:mailer].to_s
      assert_equal "broken", notifications.first[:data][:action]
      assert_equal "deliver_now", notifications.first[:data][:delivery_method]
    end
  end

  test "error report mailer avoids recursive reporting delivery job" do
    assert_equal ActionMailer::MailDeliveryJob, ErrorReportMailer.delivery_job
  end
end
