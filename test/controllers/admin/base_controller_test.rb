require "test_helper"

class Admin::BaseControllerTest < ActionDispatch::IntegrationTest
  test "requires manager login for admin pages" do
    get admin_root_path

    assert_redirected_to admin_login_path
    assert_equal I18n.t("admin.sessions.flash.require_login"), flash[:alert]
  end
end
