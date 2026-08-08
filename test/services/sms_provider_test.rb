require "test_helper"
require "stringio"

class SmsProviderTest < ActiveSupport::TestCase
  FakeResponse = Data.define(:code, :body)

  class FakeHttpClient
    attr_reader :requests

    def initialize(response:)
      @response = response
      @requests = []
    end

    def request(**options)
      requests << options
      @response
    end
  end

  class FailingHttpClient
    def request(**)
      raise SocketError, "network down"
    end
  end

  test "uses mock delivery unless explicitly enabled" do
    delivery = SmsProvider::Client.new(env: {}).deliver_login_code(phone: "+34 600 111 222", code: "123456")

    assert_predicate delivery, :mock
    assert_equal "labsmobile", delivery.provider
    assert delivery.message_id.present?
    assert SmsProvider.configured?(env: {})
  end

  test "writes mock delivery details to console output" do
    output = StringIO.new
    log_output = StringIO.new
    logger = ActiveSupport::Logger.new(log_output)

    SmsProvider::Client.new(env: {}, logger: logger, output: output).deliver_login_code(
      phone: "+34 600 111 222",
      code: "654321"
    )

    assert_includes output.string, "Development SMS delivery"
    assert_includes output.string, "To: +34 600 111 222"
    assert_includes output.string, "654321"
    assert_not_includes log_output.string, "Development SMS delivery"
  end

  test "reports production sms configuration readiness" do
    assert_not SmsProvider.configured?(env: {}, allow_mock_delivery: false)
    assert_not SmsProvider.configured?(env: { "LABSMOBILE_ENABLED" => "true" }, allow_mock_delivery: false)
    assert_not SmsProvider.configured?(
      env: {
        "LABSMOBILE_ENABLED" => "true",
        "LABSMOBILE_API_URL" => "not a url",
        "LABSMOBILE_USERNAME" => "fitxa@example.test",
        "LABSMOBILE_API_TOKEN" => "secret"
      },
      allow_mock_delivery: false
    )
    assert SmsProvider.configured?(
      env: {
        "LABSMOBILE_ENABLED" => "true",
        "LABSMOBILE_USERNAME" => "fitxa@example.test",
        "LABSMOBILE_API_TOKEN" => "secret"
      },
      allow_mock_delivery: false
    )
  end

  test "posts sms through labs mobile json endpoint" do
    response = FakeResponse.new(200, { "subid" => "abc-123", "code" => "0", "message" => "sent" }.to_json)
    http_client = FakeHttpClient.new(response: response)
    env = {
      "LABSMOBILE_ENABLED" => "true",
      "LABSMOBILE_USERNAME" => "fitxa@example.test",
      "LABSMOBILE_API_TOKEN" => "secret",
      "LABSMOBILE_SENDER" => "FitxaCAE"
    }

    delivery = SmsProvider::Client.new(env: env, http_client: http_client).deliver_login_code(
      phone: "+34 600 111 222",
      code: "123456"
    )
    request = http_client.requests.first

    assert_not_predicate delivery, :mock
    assert_equal "abc-123", delivery.message_id
    assert_equal URI("https://api.labsmobile.com/json/send"), request[:uri]
    assert_match "123456", request[:body]["message"]
    assert_equal [ { "msisdn" => "34600111222" } ], request[:body]["recipient"]
    assert_equal "FitxaCAE", request[:body]["tpoa"]
    assert_equal "Basic #{Base64.strict_encode64("fitxa@example.test:secret")}", request[:headers]["Authorization"]
    assert_equal "application/json", request[:headers]["Content-Type"]
    assert_equal "no-cache", request[:headers]["Cache-Control"]
  end

  test "supports api url override and labs mobile test mode" do
    response = FakeResponse.new(200, { "subid" => "queued-1", "code" => 0 }.to_json)
    http_client = FakeHttpClient.new(response: response)
    env = {
      "LABSMOBILE_ENABLED" => "true",
      "LABSMOBILE_API_URL" => "https://sms.example.test/json/send",
      "LABSMOBILE_USERNAME" => "fitxa@example.test",
      "LABSMOBILE_API_TOKEN" => "secret",
      "LABSMOBILE_TEST_MODE" => "true"
    }

    delivery = SmsProvider::Client.new(env: env, http_client: http_client).deliver_login_code(
      phone: "600 111 222",
      code: "111222"
    )
    request = http_client.requests.first

    assert_equal "queued-1", delivery.message_id
    assert_equal URI("https://sms.example.test/json/send"), request[:uri]
    assert_equal [ { "msisdn" => "34600111222" } ], request[:body]["recipient"]
    assert_equal 1, request[:body]["test"]
  end

  test "converts 00 international prefix to labs mobile msisdn" do
    response = FakeResponse.new(200, { "subid" => "queued-2", "code" => "0" }.to_json)
    http_client = FakeHttpClient.new(response: response)
    env = {
      "LABSMOBILE_ENABLED" => "true",
      "LABSMOBILE_USERNAME" => "fitxa@example.test",
      "LABSMOBILE_API_TOKEN" => "secret"
    }

    SmsProvider::Client.new(env: env, http_client: http_client).deliver_login_code(
      phone: "00 351 912 345 678",
      code: "111222"
    )

    assert_equal [ { "msisdn" => "351912345678" } ], http_client.requests.first[:body]["recipient"]
  end

  test "raises when enabled without credentials" do
    error = assert_raises(SmsProvider::ConfigurationError) do
      SmsProvider::Client.new(env: { "LABSMOBILE_ENABLED" => "true" }).deliver_login_code(
        phone: "+34 600 111 222",
        code: "123456"
      )
    end

    assert_match "LABSMOBILE_USERNAME", error.message
  end

  test "raises delivery error for non successful http responses" do
    response = FakeResponse.new(500, "failed")
    http_client = FakeHttpClient.new(response: response)
    env = {
      "LABSMOBILE_ENABLED" => "true",
      "LABSMOBILE_USERNAME" => "fitxa@example.test",
      "LABSMOBILE_API_TOKEN" => "secret"
    }

    error = assert_raises(SmsProvider::DeliveryError) do
      SmsProvider::Client.new(env: env, http_client: http_client).deliver_login_code(
        phone: "+34 600 111 222",
        code: "123456"
      )
    end

    assert_equal response, error.response
    assert_match "HTTP 500", error.message
  end

  test "raises delivery error for labs mobile json errors" do
    response = FakeResponse.new(200, { "subid" => "failed-1", "code" => "35", "message" => "No credits" }.to_json)
    http_client = FakeHttpClient.new(response: response)
    env = {
      "LABSMOBILE_ENABLED" => "true",
      "LABSMOBILE_USERNAME" => "fitxa@example.test",
      "LABSMOBILE_API_TOKEN" => "secret"
    }

    error = assert_raises(SmsProvider::DeliveryError) do
      SmsProvider::Client.new(env: env, http_client: http_client).deliver_login_code(
        phone: "+34 600 111 222",
        code: "123456"
      )
    end

    assert_equal response, error.response
    assert_match "LabsMobile code 35", error.message
    assert_match "No credits", error.message
  end

  test "wraps transport errors" do
    env = {
      "LABSMOBILE_ENABLED" => "true",
      "LABSMOBILE_USERNAME" => "fitxa@example.test",
      "LABSMOBILE_API_TOKEN" => "secret"
    }

    error = assert_raises(SmsProvider::Error) do
      SmsProvider::Client.new(env: env, http_client: FailingHttpClient.new).deliver_login_code(
        phone: "+34 600 111 222",
        code: "123456"
      )
    end

    assert_match "network down", error.message
  end
end
