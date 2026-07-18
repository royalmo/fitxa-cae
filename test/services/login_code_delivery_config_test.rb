require "test_helper"

class LoginCodeDeliveryConfigTest < ActiveSupport::TestCase
  test "allows test delivery explicitly" do
    assert LoginCodeDeliveryConfig.configured?("email")
    assert LoginCodeDeliveryConfig.configured?("sms")
  end

  test "rejects default smtp localhost when test delivery is not allowed" do
    assert_not LoginCodeDeliveryConfig.email_configured?(allow_test_delivery: false)
  end

  test "rejects disabled sms when mock delivery is not allowed" do
    assert_not LoginCodeDeliveryConfig.configured?("sms", allow_test_delivery: false)
  end

  test "accepts configured non local smtp" do
    with_action_mailer_delivery_config(
      delivery_method: :smtp,
      smtp_settings: { address: "smtp.example.test", port: 587 }
    ) do
      assert LoginCodeDeliveryConfig.email_configured?(allow_test_delivery: false)
    end
  end

  private

  def with_action_mailer_delivery_config(delivery_method:, smtp_settings:)
    original_delivery_method = ActionMailer::Base.delivery_method
    original_smtp_settings = ActionMailer::Base.smtp_settings

    ActionMailer::Base.delivery_method = delivery_method
    ActionMailer::Base.smtp_settings = smtp_settings
    yield
  ensure
    ActionMailer::Base.delivery_method = original_delivery_method
    ActionMailer::Base.smtp_settings = original_smtp_settings
  end
end
