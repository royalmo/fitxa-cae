require "test_helper"

class FrontendPagesTest < ActionDispatch::IntegrationTest
  test "employee pages render" do
    log_in_employee

    get root_path
    assert_response :success
    assert_select "h1", text: /Hola/
    assert_select "link[rel='stylesheet'][href*='application']", 1
    assert_select "link[rel='stylesheet'][href*='admin']", 0
    assert_select "script[src*='admin']", 0
    assert_select ".employee-nav svg.icon", 4
    assert_select ".clock-card svg.icon"
    assert_no_match %("admin":), response.body
    assert_no_match "Previst", response.body
    assert_no_match "Balanç", response.body
    assert_no_match "connexió", response.body
    assert_no_match "sincron", response.body

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
    assert_no_match "Horari", response.body

    get new_admin_employee_path
    assert_response :success
    assert_select "form"
    assert_no_match "Horari", response.body

    get admin_reports_path
    assert_response :success
    assert_select "h1", text: "Informes de fitxatges"
    assert_no_match "Balanç", response.body
    assert_no_match "Incidències", response.body

    get admin_corrections_path
    assert_response :success
    assert_select "table"
  end

  test "no-op actions redirect to their list screens" do
    log_in_employee

    post clock_out_path
    assert_redirected_to root_path

    assert_difference "SwipeCorrection.count", 1 do
      post corrections_path, params: {
        date: Date.current.iso8601,
        kind: "missing_exit",
        time: "17:00",
        note: "Sortida oblidada"
      }
    end
    assert_redirected_to corrections_path

    assert_difference "Employee.count", 1 do
      post admin_employees_path, params: {
        employee: {
          first_name: "Joan",
          last_name: "Mas",
          national_id: valid_dni(40_000_001),
          active: "1"
        }
      }
    end
    assert_redirected_to admin_employees_path

    employee = create_employee(national_id: valid_dni(40_000_002), password: "1234")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.current,
      details: {
        "requested_swipes" => [
          { "kind" => "exit", "swipe_at" => Time.current.iso8601 }
        ]
      }
    )

    post approve_admin_correction_path(correction)
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
    assert_match "\"#{unavailable_path}\"", response.body
    assert_no_match "offline", response.body

    get unavailable_path
    assert_response :success
    assert_select "h1", text: "No s'ha pogut carregar"
    assert_select ".employee-nav", 0
    assert_no_match "connexió", response.body
    assert_no_match "sincron", response.body
  end
end
