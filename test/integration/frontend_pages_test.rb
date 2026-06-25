require "test_helper"

class FrontendPagesTest < ActionDispatch::IntegrationTest
  test "employee pages render" do
    get root_path
    assert_response :success
    assert_select "h1", text: /Hola/
    assert_select "link[rel='stylesheet'][href*='application']", 1
    assert_select "link[rel='stylesheet'][href*='admin']", 0
    assert_select "script[src*='admin']", 0
    assert_no_match %("admin":), response.body

    get clockings_path
    assert_response :success
    assert_select "h1", text: "Historial"

    get corrections_path
    assert_response :success
    assert_select "h1", text: "Correccions"

    get new_correction_path
    assert_response :success
    assert_select "form"

    get account_path
    assert_response :success
    assert_select "h1", text: "Compte"
  end

  test "admin pages render" do
    get admin_root_path
    assert_response :success
    assert_select "h1", text: "Resum operatiu"
    assert_select "link[rel='stylesheet'][href*='application']", 1
    assert_select "link[rel='stylesheet'][href*='admin']", 1
    assert_select "script[src*='admin']", 1

    get admin_employees_path
    assert_response :success
    assert_select "table"

    get new_admin_employee_path
    assert_response :success
    assert_select "form"

    get admin_reports_path
    assert_response :success
    assert_select "h1", text: "Informes horaris"

    get admin_corrections_path
    assert_response :success
    assert_select "table"
  end

  test "no-op actions redirect to their list screens" do
    post clock_out_path
    assert_redirected_to root_path

    post corrections_path
    assert_redirected_to corrections_path

    post admin_employees_path
    assert_redirected_to admin_employees_path

    post approve_admin_correction_path(501)
    assert_redirected_to admin_corrections_path
  end

  test "pwa endpoints render" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    assert_match "Fitxa CAE", response.body

    get pwa_service_worker_path(format: :js)
    assert_response :success
    assert_match "startsWith(\"/admin\")", response.body
    assert_no_match "<%=", response.body
    assert_no_match "&quot;", response.body
    assert_match "\"#{offline_path}\"", response.body

    get offline_path
    assert_response :success
    assert_select "h1", text: "Sense connexió"
  end
end
