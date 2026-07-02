require "test_helper"

class SmsArenaTest < ActiveSupport::TestCase
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
    delivery = SmsArena::Client.new(env: {}).deliver_login_code(phone: "+34 600 111 222", code: "123456")

    assert_predicate delivery, :mock
    assert_equal "smsarena", delivery.provider
    assert delivery.message_id.present?
  end

  test "posts sms through configured smsarena endpoint" do
    response = FakeResponse.new(200, { "message_id" => "abc-123" }.to_json)
    http_client = FakeHttpClient.new(response: response)
    env = {
      "SMSARENA_ENABLED" => "true",
      "SMSARENA_API_URL" => "https://panel.smsarena.es/api/sms",
      "SMSARENA_API_KEY" => "secret",
      "SMSARENA_SENDER" => "FitxaCAE"
    }

    delivery = SmsArena::Client.new(env: env, http_client: http_client).deliver_login_code(
      phone: "+34 600 111 222",
      code: "123456"
    )
    request = http_client.requests.first

    assert_not_predicate delivery, :mock
    assert_equal "abc-123", delivery.message_id
    assert_equal URI("https://panel.smsarena.es/api/sms"), request[:uri]
    assert_equal "post", request[:method]
    assert_equal "+34600111222", request[:params]["to"]
    assert_match "123456", request[:params]["message"]
    assert_equal "secret", request[:params]["api_key"]
    assert_equal "FitxaCAE", request[:params]["from"]
  end

  test "supports custom parameter names and get requests" do
    response = FakeResponse.new(200, "queued-1")
    http_client = FakeHttpClient.new(response: response)
    env = {
      "SMSARENA_ENABLED" => "true",
      "SMSARENA_API_URL" => "https://panel.smsarena.es/api/send",
      "SMSARENA_HTTP_METHOD" => "get",
      "SMSARENA_TO_PARAM" => "destination",
      "SMSARENA_MESSAGE_PARAM" => "text",
      "SMSARENA_API_KEY_PARAM" => "token",
      "SMSARENA_API_KEY" => "secret"
    }

    delivery = SmsArena::Client.new(env: env, http_client: http_client).deliver_login_code(
      phone: "600 111 222",
      code: "111222"
    )
    request = http_client.requests.first

    assert_equal "queued-1", delivery.message_id
    assert_equal "get", request[:method]
    assert_equal "600111222", request[:params]["destination"]
    assert_match "111222", request[:params]["text"]
    assert_equal "secret", request[:params]["token"]
  end

  test "supports basic authentication" do
    response = FakeResponse.new(200, "")
    http_client = FakeHttpClient.new(response: response)
    env = {
      "SMSARENA_ENABLED" => "true",
      "SMSARENA_API_URL" => "https://panel.smsarena.es/api/sms",
      "SMSARENA_AUTH_MODE" => "basic",
      "SMSARENA_USERNAME" => "fitxa",
      "SMSARENA_PASSWORD" => "secret"
    }

    SmsArena::Client.new(env: env, http_client: http_client).deliver_login_code(
      phone: "+34 600 111 222",
      code: "123456"
    )
    request = http_client.requests.first

    assert_equal "Basic #{Base64.strict_encode64("fitxa:secret")}", request[:headers]["Authorization"]
    assert_not request[:params].key?("username")
    assert_not request[:params].key?("password")
  end

  test "raises when enabled without endpoint" do
    error = assert_raises(SmsArena::ConfigurationError) do
      SmsArena::Client.new(env: { "SMSARENA_ENABLED" => "true" }).deliver_login_code(
        phone: "+34 600 111 222",
        code: "123456"
      )
    end

    assert_match "SMSARENA_API_URL", error.message
  end

  test "raises delivery error for non successful responses" do
    response = FakeResponse.new(500, "failed")
    http_client = FakeHttpClient.new(response: response)
    env = {
      "SMSARENA_ENABLED" => "true",
      "SMSARENA_API_URL" => "https://panel.smsarena.es/api/sms"
    }

    error = assert_raises(SmsArena::DeliveryError) do
      SmsArena::Client.new(env: env, http_client: http_client).deliver_login_code(
        phone: "+34 600 111 222",
        code: "123456"
      )
    end

    assert_equal response, error.response
  end

  test "wraps transport errors" do
    env = {
      "SMSARENA_ENABLED" => "true",
      "SMSARENA_API_URL" => "https://panel.smsarena.es/api/sms"
    }

    error = assert_raises(SmsArena::Error) do
      SmsArena::Client.new(env: env, http_client: FailingHttpClient.new).deliver_login_code(
        phone: "+34 600 111 222",
        code: "123456"
      )
    end

    assert_match "network down", error.message
  end
end
