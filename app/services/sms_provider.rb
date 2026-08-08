require "base64"
require "json"
require "net/http"
require "openssl"
require "securerandom"
require "uri"

module SmsProvider
  DEFAULT_API_URL = "https://api.labsmobile.com/json/send"

  Delivery = Data.define(:provider, :message_id, :mock, :response_code, :response_body)

  class Error < StandardError; end
  class ConfigurationError < Error; end

  class DeliveryError < Error
    attr_reader :response

    def initialize(response)
      @response = response

      super("SMS provider delivery failed with #{failure_detail}")
    end

    private

    def failure_detail
      details = []
      details << "HTTP #{response.code}" if response.respond_to?(:code)

      if response.respond_to?(:body)
        body = JSON.parse(response.body.to_s)
        if body.is_a?(Hash)
          details << "LabsMobile code #{body["code"]}" if body["code"].present?
          details << body["message"] if body["message"].present?
        end
      end

      details.compact_blank.join(": ").presence || "provider response"
    rescue JSON::ParserError
      details = []
      details << "HTTP #{response.code}" if response.respond_to?(:code)
      details << response.body.to_s[0, 120] if response.respond_to?(:body) && response.body.present?
      details.compact_blank.join(": ").presence || "provider response"
    end
  end

  module_function

  def deliver_login_code(phone:, code:)
    Client.new.deliver_login_code(phone: phone, code: code)
  end

  def configured?(env: ENV, allow_mock_delivery: Rails.env.test?)
    enabled = enabled?(env)
    return true if allow_mock_delivery && !enabled
    return false unless enabled

    configured_api_url?(api_url(env)) &&
      env["LABSMOBILE_USERNAME"].present? &&
      env["LABSMOBILE_API_TOKEN"].present?
  end

  def enabled?(env = ENV)
    ActiveModel::Type::Boolean.new.cast(env.fetch("LABSMOBILE_ENABLED", false))
  end

  def api_url(env)
    env["LABSMOBILE_API_URL"].presence || DEFAULT_API_URL
  end
  private_class_method :api_url

  def configured_api_url?(endpoint)
    uri = URI.parse(endpoint.to_s)

    uri.host.present? && %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    false
  end
  private_class_method :configured_api_url?

  class Client
    def initialize(logger: Rails.logger, http_client: HttpClient.new, env: ENV, output: Rails.env.development? ? $stdout : nil)
      @logger = logger
      @http_client = http_client
      @env = env
      @output = output
    end

    def deliver_login_code(phone:, code:)
      message = I18n.t("employee.sessions.sms.body", code: code, minutes: Employee::LOGIN_CODE_TTL.in_minutes.to_i)

      return mock_delivery(phone: phone, message: message) unless enabled?

      response = http_client.request(
        uri: uri,
        body: request_body(phone: phone, message: message),
        headers: request_headers,
        timeout: timeout
      )
      raise DeliveryError, response unless success_response?(response)

      Delivery.new(
        provider: "labsmobile",
        message_id: response_message_id(response),
        mock: false,
        response_code: response.code.to_i,
        response_body: response.body
      )
    rescue IOError, OpenSSL::SSL::SSLError, SocketError, SystemCallError, Timeout::Error => error
      raise Error, "LabsMobile request failed: #{error.class}: #{error.message}"
    end

    private

    attr_reader :logger, :http_client, :env, :output

    def mock_delivery(phone:, message:)
      console_message = <<~MESSAGE

        === Development SMS delivery ===
        To: #{phone}

        #{message}
        === End development SMS delivery ===
      MESSAGE
      write_to_console(console_message)

      Delivery.new(
        provider: "labsmobile",
        message_id: SecureRandom.uuid,
        mock: true,
        response_code: nil,
        response_body: nil
      )
    end

    def write_to_console(message)
      return unless output

      output.write(message)
      output.flush if output.respond_to?(:flush)
    end

    def enabled?
      SmsProvider.enabled?(env)
    end

    def uri
      @uri ||= begin
        URI.parse(env["LABSMOBILE_API_URL"].presence || DEFAULT_API_URL)
      rescue URI::InvalidURIError => error
        raise ConfigurationError, "LABSMOBILE_API_URL is invalid: #{error.message}"
      end
    end

    def request_body(phone:, message:)
      {
        "message" => message,
        "recipient" => [
          { "msisdn" => normalized_phone(phone) }
        ]
      }.tap do |body|
        body["tpoa"] = sender if sender
        body["test"] = 1 if test_mode?
      end
    end

    def request_headers
      {
        "Authorization" => "Basic #{basic_auth_token}",
        "Cache-Control" => "no-cache",
        "Content-Type" => "application/json"
      }
    end

    def basic_auth_token
      Base64.strict_encode64("#{required_env("LABSMOBILE_USERNAME")}:#{required_env("LABSMOBILE_API_TOKEN")}")
    end

    def required_env(name)
      env[name].presence || raise(ConfigurationError, "#{name} is required for LabsMobile SMS delivery")
    end

    def normalized_phone(phone)
      digits = phone.to_s.gsub(/\D/, "")
      digits = digits.delete_prefix("00")

      return digits if digits.length > 9

      "34#{digits}"
    end

    def sender
      env["LABSMOBILE_SENDER"].presence
    end

    def test_mode?
      ActiveModel::Type::Boolean.new.cast(env.fetch("LABSMOBILE_TEST_MODE", false))
    end

    def timeout
      env.fetch("LABSMOBILE_TIMEOUT", 10).to_i
    end

    def success_response?(response)
      return false unless response.code.to_i.between?(200, 299)

      body = response_body(response)
      body.is_a?(Hash) && body["code"].to_s == "0"
    rescue JSON::ParserError
      false
    end

    def response_message_id(response)
      body = response_body(response)
      body["subid"]
    rescue JSON::ParserError
      nil
    end

    def response_body(response)
      JSON.parse(response.body.to_s)
    end
  end

  class HttpClient
    def request(uri:, body:, headers:, timeout:)
      request = Net::HTTP::Post.new(uri)
      headers.each { |key, value| request[key] = value }
      request.body = JSON.dump(body)

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout,
        read_timeout: timeout
      ) do |http|
        http.request(request)
      end
    end
  end
end
