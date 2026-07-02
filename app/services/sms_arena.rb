require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

module SmsArena
  Delivery = Data.define(:provider, :message_id, :mock, :response_code, :response_body)

  class Error < StandardError; end
  class ConfigurationError < Error; end

  class DeliveryError < Error
    attr_reader :response

    def initialize(response)
      @response = response

      super("SMSArena delivery failed with HTTP #{response.code}")
    end
  end

  module_function

  def deliver_login_code(phone:, code:)
    Client.new.deliver_login_code(phone: phone, code: code)
  end

  class Client
    def initialize(logger: Rails.logger, http_client: HttpClient.new, env: ENV)
      @logger = logger
      @http_client = http_client
      @env = env
    end

    def deliver_login_code(phone:, code:)
      message = I18n.t("employee.sessions.sms.body", code: code, minutes: Employee::LOGIN_CODE_TTL.in_minutes.to_i)

      return mock_delivery(phone: phone, message: message) unless enabled?

      response = http_client.request(
        uri: uri,
        method: http_method,
        params: request_params(phone: phone, message: message),
        headers: request_headers,
        timeout: timeout
      )
      raise DeliveryError, response unless success_response?(response)

      Delivery.new(
        provider: "smsarena",
        message_id: response_message_id(response),
        mock: false,
        response_code: response.code.to_i,
        response_body: response.body
      )
    rescue IOError, OpenSSL::SSL::SSLError, SocketError, SystemCallError, Timeout::Error => error
      raise Error, "SMSArena request failed: #{error.class}: #{error.message}"
    end

    private

    attr_reader :logger, :http_client, :env

    def mock_delivery(phone:, message:)
      logger.info("[SMSArena mock] to=#{phone} body=#{message}")

      Delivery.new(
        provider: "smsarena",
        message_id: SecureRandom.uuid,
        mock: true,
        response_code: nil,
        response_body: nil
      )
    end

    def enabled?
      ActiveModel::Type::Boolean.new.cast(env.fetch("SMSARENA_ENABLED", false))
    end

    def uri
      @uri ||= begin
        endpoint = env["SMSARENA_API_URL"].presence
        raise ConfigurationError, "SMSARENA_API_URL is required when SMSARENA_ENABLED=true" unless endpoint

        URI.parse(endpoint)
      rescue URI::InvalidURIError => error
        raise ConfigurationError, "SMSARENA_API_URL is invalid: #{error.message}"
      end
    end

    def request_params(phone:, message:)
      {
        to_param => normalized_phone(phone),
        message_param => message
      }.merge(sender_params).merge(credential_params)
    end

    def sender_params
      sender = env["SMSARENA_SENDER"].presence
      sender ? { sender_param => sender } : {}
    end

    def credential_params
      return {} unless auth_mode == "params"

      {
        api_key_param => env["SMSARENA_API_KEY"].presence,
        username_param => env["SMSARENA_USERNAME"].presence,
        password_param => env["SMSARENA_PASSWORD"].presence
      }.compact
    end

    def request_headers
      case auth_mode
      when "basic"
        { "Authorization" => "Basic #{basic_auth_token}" }
      when "bearer"
        { "Authorization" => "Bearer #{required_env("SMSARENA_API_KEY")}" }
      else
        {}
      end
    end

    def auth_mode
      env.fetch("SMSARENA_AUTH_MODE", "params").to_s
    end

    def basic_auth_token
      Base64.strict_encode64("#{required_env("SMSARENA_USERNAME")}:#{required_env("SMSARENA_PASSWORD")}")
    end

    def required_env(name)
      env[name].presence || raise(ConfigurationError, "#{name} is required for SMSArena #{auth_mode} authentication")
    end

    def normalized_phone(phone)
      phone.to_s.gsub(/[^\d+]/, "")
    end

    # TODO This is very spaghetti, we can hardcode stuff I think.
    def http_method
      env.fetch("SMSARENA_HTTP_METHOD", "post").to_s.downcase
    end

    def timeout
      env.fetch("SMSARENA_TIMEOUT", 10).to_i
    end

    def to_param
      env.fetch("SMSARENA_TO_PARAM", "to")
    end

    def message_param
      env.fetch("SMSARENA_MESSAGE_PARAM", "message")
    end

    def sender_param
      env.fetch("SMSARENA_SENDER_PARAM", "from")
    end

    def api_key_param
      env.fetch("SMSARENA_API_KEY_PARAM", "api_key")
    end

    def username_param
      env.fetch("SMSARENA_USERNAME_PARAM", "username")
    end

    def password_param
      env.fetch("SMSARENA_PASSWORD_PARAM", "password")
    end

    def success_response?(response)
      response.code.to_i.between?(200, 299)
    end

    def response_message_id(response)
      body = JSON.parse(response.body)
      body["message_id"] || body["messageId"] || body["id"] || body["sms_id"] || body["smsId"]
    rescue JSON::ParserError
      response.body.to_s.lines.first&.strip.presence
    end
  end

  class HttpClient
    def request(uri:, method:, params:, headers:, timeout:)
      uri = uri.dup
      request = build_request(uri: uri, method: method, params: params)
      headers.each { |key, value| request[key] = value }

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

    private

    def build_request(uri:, method:, params:)
      case method
      when "get"
        uri.query = [ uri.query, URI.encode_www_form(params) ].compact_blank.join("&")
        Net::HTTP::Get.new(uri)
      else
        Net::HTTP::Post.new(uri).tap { |request| request.set_form_data(params) }
      end
    end
  end
end
