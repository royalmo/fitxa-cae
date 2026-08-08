# frozen_string_literal: true

require "test_helper"
require "canonical_host_redirect"

class CanonicalHostRedirectTest < ActiveSupport::TestCase
  test "permanently redirects configured hosts to the canonical host" do
    middleware = CanonicalHostRedirect.new(
      passthrough_app,
      redirect_hosts: "fitxar.cae.cat",
      target_host: "fitxa.cae.cat",
      target_protocol: "https"
    )

    status, headers, body = middleware.call(
      Rack::MockRequest.env_for("http://fitxar.cae.cat/admin?return_to=%2F")
    )

    assert_equal 301, status
    assert_equal "https://fitxa.cae.cat/admin?return_to=%2F", headers["location"]
    assert_empty body
  end

  test "passes canonical host requests through" do
    status, headers, body = CanonicalHostRedirect.new(
      passthrough_app,
      redirect_hosts: "fitxar.cae.cat",
      target_host: "fitxa.cae.cat"
    ).call(Rack::MockRequest.env_for("https://fitxa.cae.cat/"))

    assert_equal 200, status
    assert_equal({ "content-type" => "text/plain" }, headers)
    assert_equal [ "ok" ], body
  end

  test "accepts comma separated redirect hosts and normalizes case" do
    middleware = CanonicalHostRedirect.new(
      passthrough_app,
      redirect_hosts: " FITXAR.CAE.CAT. , unused.example ",
      target_host: "fitxa.cae.cat"
    )

    status, headers = middleware.call(Rack::MockRequest.env_for("http://fitxar.cae.cat/clockings"))

    assert_equal 301, status
    assert_equal "https://fitxa.cae.cat/clockings", headers["location"]
  end

  private
    def passthrough_app
      ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "ok" ] ] }
    end
end
