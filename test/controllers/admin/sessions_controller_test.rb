require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "renders login page" do
    get admin_login_path

    assert_response :success
    assert_select "title", text: "Accés de gestió | FitxaCAE Admin"
    assert_select "form[action='#{admin_login_path}']"
  end

  test "signs in an active manager and returns to requested admin page" do
    manager = create_manager(email: "laia.riera@example.test")

    get admin_employees_path
    assert_redirected_to admin_login_path

    post admin_login_path, params: {
      email: " LAIA.RIERA@EXAMPLE.TEST ",
      password: "12345678"
    }

    assert_redirected_to admin_employees_path
    follow_redirect!
    assert_response :success
    assert_match "Laia Riera", response.body
  end

  test "head request to admin page stores return path" do
    manager = create_manager(email: "laia.riera@example.test")

    head admin_employees_path
    assert_redirected_to admin_login_path

    post admin_login_path, params: {
      email: manager.email,
      password: "12345678"
    }

    assert_redirected_to admin_employees_path
  end

  test "rejects invalid credentials and inactive managers" do
    manager = create_manager(email: "laia.riera@example.test")
    inactive = create_manager(email: "inactive@example.test", active: false)

    post admin_login_path, params: { email: manager.email, password: "bad" }
    assert_response :unprocessable_entity

    post admin_login_path, params: { email: inactive.email, password: "12345678" }
    assert_response :unprocessable_entity
  end

  test "signs out manager" do
    log_in_manager

    delete admin_logout_path

    assert_redirected_to admin_login_path
    assert_equal I18n.t("admin.sessions.destroy.signed_out"), flash[:notice]

    get admin_root_path
    assert_redirected_to admin_login_path
  end
end
