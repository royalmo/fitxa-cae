require "test_helper"

class DualRoleSessionTest < ActionDispatch::IntegrationTest
  test "employee and manager can stay signed in when manager logs in second" do
    employee = create_employee(password: "1234")
    manager = create_manager(email: "manager@example.test", password: "12345678")

    post login_path, params: {
      national_id: employee.national_id,
      password: "1234"
    }
    assert_redirected_to root_path

    post admin_login_path, params: {
      email: manager.email,
      password: "12345678"
    }
    assert_redirected_to admin_root_path

    get root_path
    assert_response :success
    assert_select ".employee-topbar a.employee-chip", text: /Ada Soler/

    get admin_root_path
    assert_response :success
    assert_select "nav.navbar a[href='#{admin_account_path}']", text: /Laia Riera/
  end

  test "employee and manager can stay signed in when employee logs in second" do
    employee = create_employee(password: "1234")
    manager = create_manager(email: "manager@example.test", password: "12345678")

    post admin_login_path, params: {
      email: manager.email,
      password: "12345678"
    }
    assert_redirected_to admin_root_path

    post login_path, params: {
      national_id: employee.national_id,
      password: "1234"
    }
    assert_redirected_to root_path

    get admin_root_path
    assert_response :success

    get root_path
    assert_response :success
  end

  test "signing out employee does not sign out manager" do
    employee = create_employee(password: "1234")
    manager = create_manager(email: "manager@example.test", password: "12345678")

    post login_path, params: { national_id: employee.national_id, password: "1234" }
    post admin_login_path, params: { email: manager.email, password: "12345678" }

    delete logout_path

    assert_redirected_to login_path
    get admin_root_path
    assert_response :success
    get root_path
    assert_redirected_to login_path
  end

  test "signing out manager does not sign out employee" do
    employee = create_employee(password: "1234")
    manager = create_manager(email: "manager@example.test", password: "12345678")

    post login_path, params: { national_id: employee.national_id, password: "1234" }
    post admin_login_path, params: { email: manager.email, password: "12345678" }

    delete admin_logout_path

    assert_redirected_to admin_login_path
    get root_path
    assert_response :success
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "manager remember me does not rewrite employee auth cookie" do
    employee = create_employee(password: "1234")
    manager = create_manager(email: "manager@example.test", password: "12345678")

    post login_path, params: { national_id: employee.national_id, password: "1234" }
    employee_login_cookies = Array(response.headers["Set-Cookie"]).join("\n")
    assert_match(/fitxa_cae_employee_id=/, employee_login_cookies)
    assert_no_match(/fitxa_cae_manager_id=/, employee_login_cookies)

    travel_to Time.zone.local(2026, 7, 1, 9, 0) do
      post admin_login_path, params: {
        email: manager.email,
        password: "12345678",
        remember_me: "1"
      }
    end

    manager_login_cookies = Array(response.headers["Set-Cookie"]).join("\n")
    assert_match(/fitxa_cae_manager_id=.*expires=.*31 Jul 2026/i, manager_login_cookies)
    assert_no_match(/fitxa_cae_employee_id=/, manager_login_cookies)
  end
end
