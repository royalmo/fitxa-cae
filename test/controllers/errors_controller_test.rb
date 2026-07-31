require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "renders not found with employee layout and minimal content" do
    get "/errors/404"

    assert_response :not_found
    assert_select ".employee-topbar"
    assert_select ".employee-nav"
    assert_select ".employee-chip", false
    assert_select "a.employee-login-button[href='#{login_path}']", "Entrar"
    assert_select ".error-page-code", false
    assert_select "h1", "No hem trobat aquesta pantalla."
    assert_select ".error-page-layout > p"
    assert_select "a", "Torna a l'inici"
  end

  test "renders internal server error with support action" do
    get "/errors/500"

    assert_response :internal_server_error
    assert_select ".error-page-code", false
    assert_select "a[href^='mailto:rrhh@cae.cat']", "Contacta amb RRHH"
  end

  test "renders signed in employee topbar controls when available" do
    employee = create_employee(first_name: "Ada", password: "1234")

    log_in_employee(employee)
    get "/errors/404"

    assert_response :not_found
    assert_select ".employee-chip", text: /Ada/
    assert_select ".employee-logout-button"
  end

  test "renders admin layout for direct admin error paths" do
    manager = create_manager(first_name: "Laia", last_name: "Riera")

    log_in_manager(manager)
    get "/admin/404"

    assert_response :not_found
    assert_select ".employee-topbar", false
    assert_select ".navbar .admin-brand"
    assert_select "aside#adminSidebar"
    assert_select ".admin-topbar-actions", text: /Laia Riera/
    assert_select "h1", "No hem trobat aquesta pantalla."
    assert_select "a.btn.btn-primary[href='#{admin_root_path}']", "Torna a l'inici"
    assert_select "a.btn.btn-outline-secondary[href^='mailto:rrhh@cae.cat']", "Contacta amb RRHH"
  end

  test "exceptions app renders dynamic employee page" do
    env = Rails.application.env_config.merge(Rack::MockRequest.env_for("/404"))
    status, _headers, body = Rails.application.config.exceptions_app.call(env)
    html = body.each.to_a.join

    assert_equal 404, status
    assert_includes html, "brand-logo"
    assert_includes html, "No hem trobat aquesta pantalla."
    assert_includes html, "employee-login-button"
    assert_includes html, "Entrar"
    assert_not_includes html, "Treballador"
    assert_includes html, "Torna a l&#39;inici"
    assert_includes html, "Contacta amb RRHH"
  end

  test "exceptions app uses admin layout for original admin paths" do
    env = Rails.application.env_config.merge(Rack::MockRequest.env_for("/404"))
    env["action_dispatch.original_path"] = "/admin/corrections/missing"
    status, _headers, body = Rails.application.config.exceptions_app.call(env)
    html = body.each.to_a.join

    assert_equal 404, status
    assert_includes html, "FitxaCAE Admin"
    assert_includes html, "adminSidebar"
    assert_includes html, "No hem trobat aquesta pantalla."
    assert_includes html, "href=\"/admin\""
    assert_includes html, "href=\"/admin/login\""
    assert_not_includes html, "/admin/logout"
    assert_not_includes html, "employee-topbar"
  end
end
