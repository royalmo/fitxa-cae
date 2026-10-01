require "test_helper"

class BrowserCompatibilityTest < ActionDispatch::IntegrationTest
  COMPATIBLE_IPHONE_SAFARI = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_7_16 like Mac OS X) " \
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6.2 Mobile/15E148 Safari/604.1"
  TOO_OLD_IPHONE_SAFARI = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_3 like Mac OS X) " \
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Mobile/15E148 Safari/604.1"
  TOO_OLD_CHROME = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36"
  SELF_MADE_USER_AGENT = "FitxaAuditProbe/1.0"

  test "allows compatible employee browsers below Rails modern preset" do
    get login_path, headers: user_agent_headers(COMPATIBLE_IPHONE_SAFARI)

    assert_response :success
  end

  test "allows compatible admin browsers below Rails modern preset" do
    get admin_login_path, headers: user_agent_headers(COMPATIBLE_IPHONE_SAFARI)

    assert_response :success
  end

  test "blocks guarded browsers below the compatibility floor" do
    get login_path, headers: user_agent_headers(TOO_OLD_IPHONE_SAFARI)

    assert_response :not_acceptable

    get admin_login_path, headers: user_agent_headers(TOO_OLD_CHROME)

    assert_response :not_acceptable
  end

  test "allows unguarded or custom user agents" do
    get login_path, headers: user_agent_headers("curl/8.5.0")

    assert_response :success

    get admin_login_path, headers: user_agent_headers(SELF_MADE_USER_AGENT)

    assert_response :success
  end

  private

  def user_agent_headers(user_agent)
    { "HTTP_USER_AGENT" => user_agent }
  end
end
