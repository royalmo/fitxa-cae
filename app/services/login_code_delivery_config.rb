module LoginCodeDeliveryConfig
  DELIVERY_METHODS = %w[email sms].freeze

  class ConfigurationError < StandardError; end

  module_function

  def configured?(delivery_method, allow_test_delivery: Rails.env.test?)
    case delivery_method.to_s
    when "email"
      email_configured?(allow_test_delivery: allow_test_delivery)
    when "sms"
      SmsArena.configured?(allow_mock_delivery: allow_test_delivery)
    else
      false
    end
  end

  def email_configured?(allow_test_delivery: Rails.env.test?)
    return true if allow_test_delivery
    return false unless ActionMailer::Base.perform_deliveries

    case ActionMailer::Base.delivery_method.to_sym
    when :smtp
      smtp_settings = ActionMailer::Base.smtp_settings
      smtp_settings[:address].present? && smtp_settings[:address] != "localhost"
    when :test, :file
      false
    else
      true
    end
  end
end
