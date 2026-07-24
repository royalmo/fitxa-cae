require "test_helper"

class FrontendPagesTest < ActionDispatch::IntegrationTest
  test "employee pages render" do
    log_in_employee

    get root_path
    assert_response :success
    assert_select "title", text: "Avui | FitxaCAE"
    assert_select "h1", text: "Hola, Ada"
    assert_select ".today-date time"
    assert_select ".today-intro-meta", 0
    assert_select ".today-total", 0
    assert_select ".today-punch-button[data-controller='punch-timer'][data-punch-timer-base-seconds-value='0']"
    assert_select ".today-punch-button[data-punch-timer-started-at-value]", 0
    assert_select ".today-punch-button .today-punch-action-row .today-punch-label", text: "Entrar"
    assert_select ".today-punch-button .today-punch-duration-number.is-hours[data-punch-timer-target='hours']", text: "0"
    assert_select ".today-punch-button .today-punch-duration-number[data-punch-timer-target='minutes']", text: "00"
    assert_select ".today-punch-button .today-punch-duration-number[data-punch-timer-target='seconds']", text: "00"
    assert_select "html[data-pwa='employee'][data-employee-signed-in='true'][data-employee-theme-preference='system'][data-theme-preference='system']"
    assert_select "body[data-controller~='employee-theme'][data-controller~='submit-feedback'][data-employee-theme-preference-value='system'][data-employee-theme-signed-in-value='true']"
    assert_select "meta[name='color-scheme'][content='light dark']"
    assert_match "localStorage.setItem(storageKey, preference)", response.body
    assert_select "link[rel='stylesheet'][href*='application']", 1
    assert_select "link[rel='stylesheet'][href*='admin']", 0
    assert_select "script[src*='admin']", 0
    assert_select ".employee-topbar .employee-topbar-inner"
    assert_select ".employee-topbar .employee-logout-button[title='Tancar sessió'][aria-label='Tancar sessió']"
    assert_select ".employee-topbar .employee-logout-button svg.icon[role='img'][aria-label='Tancar sessió']"
    assert_select ".employee-topbar .employee-logout-button", text: /Sortir/, count: 0
    assert_select ".employee-topbar a.employee-chip[href='#{account_path}'][title='Ada Soler'] span", text: "Ada Soler"
    assert_select ".employee-topbar .employee-admin-button", 0
    assert_select ".employee-topbar .icon-button", 0
    assert_select "body.employee-shell > .flash", 0
    assert_select ".employee-nav svg.icon", 4
    assert_select ".today-punch-button svg.icon"
    assert_select ".clock-action-form button.today-punch-button[type='submit'][data-submitting-label]"
    assert_select ".today-section-header h2", text: "Fitxatges d'avui"
    assert_select ".today-correction-link", text: "Corregir"
    assert_select ".today-section-header h2", text: "Resum setmanal"
    assert_select ".today-week-lines dt", text: "Correccions"
    assert_select ".today-week-lines dd a[href='#{corrections_path(month: Date.current.month, year: Date.current.year)}'] em", text: "Cap correcció."
    assert_select ".request-row", 0
    assert_no_match %("admin":), response.body
    assert_no_match "Previst", response.body
    assert_no_match "Balanç", response.body
    assert_no_match "connexió", response.body
    assert_no_match "sincron", response.body

    get clockings_path
    assert_response :success
    assert_select "title", text: "Fitxatges | FitxaCAE"
    assert_select "h1", text: "Historial"

    get corrections_path
    assert_response :success
    assert_select "title", text: "Correccions | FitxaCAE"
    assert_select "h1", text: "Correccions"

    get new_correction_path
    assert_response :success
    assert_select "title", text: "Nova correcció | FitxaCAE"
    assert_select "form"
    assert_select "form button[type='submit'][data-submitting-label='Enviant...']"

    get account_path
    assert_response :success
    assert_select "title", text: "Compte | FitxaCAE"
    assert_select "h1", text: "Compte"
    assert_select ".page-intro p", 0
    assert_select ".account-layout"
    assert_select ".account-layout .panel", 0
    assert_select ".account-layout h2", 0
    assert_select ".account-hr-contact h2", text: "Contactar amb Recursos Humans"
    assert_select ".account-save-button[data-submitting-label='Desant...']"
    assert_select ".account-hr-contact-form button[data-submitting-label='Enviant...']"
  end

  test "employee layout uses persisted theme preference" do
    employee = create_employee(password: "1234", settings: { "theme" => "dark" })
    log_in_employee(employee)

    get root_path

    assert_response :success
    assert_select "html[data-employee-signed-in='true'][data-employee-theme-preference='dark'][data-theme-preference='dark'][data-theme='dark']"
    assert_select "body[data-controller~='employee-theme'][data-employee-theme-preference-value='dark'][data-employee-theme-signed-in-value='true']"
  end

  test "employee topbar name links to account and shows full names" do
    employee = create_employee(first_name: "Maria", last_name: "Rodriguez Casals", password: "1234")
    log_in_employee(employee)

    get root_path

    assert_response :success
    assert_select ".employee-topbar a.employee-chip[href='#{account_path}'][title='Maria Rodriguez Casals'] span", text: "Maria Rodriguez Casals"
  end

  test "employee topbar links to admin when employee has a linked manager" do
    employee = create_employee(password: "1234")
    create_manager(employee: employee)
    log_in_employee(employee)

    get root_path

    assert_response :success
    assert_select ".employee-topbar .employee-admin-button[href='#{admin_root_path}'][title='Accés admin'][aria-label='Accés admin']"
    assert_select ".employee-topbar .employee-admin-button svg.icon[aria-hidden='true']"

    action_classes = css_select(".employee-topbar-actions > *").map { |node| node["class"] }
    assert_operator action_classes.index("employee-admin-button"), :<, action_classes.index("topbar-form")

    get admin_root_path

    assert_redirected_to admin_login_path
  end

  test "admin pages render" do
    log_in_manager

    get admin_root_path
    assert_response :success
    assert_select "html[data-pwa='admin'][data-theme-preference='light'][data-theme='light']"
    assert_select "body[data-controller~='admin-theme'][data-controller~='submit-feedback']"
    assert_select "meta[name='color-scheme'][content='light']"
    assert_select "title", text: "Resum | FitxaCAE Admin"
    assert_select "h1", text: "Resum operatiu"
    assert_select "link[rel='stylesheet'][href*='admin_bootstrap']", 1
    assert_select "link[rel='stylesheet'][href$='admin.css'], link[rel='stylesheet'][href*='/admin-']", 1
    assert_select "link[rel='stylesheet'][href*='application']", 0
    assert_select "script[src*='popper']", 1
    assert_select "script[src*='bootstrap']", 1
    assert_select "aside#adminSidebar.admin-sidebar.offcanvas-lg nav.nav-pills"
    assert_select "button[data-bs-toggle='offcanvas'][data-bs-target='#adminSidebar'][aria-label='Obrir menú'] svg.icon"
    assert_select ".admin-brand .brand-badge", text: "ADMIN"

    get admin_employees_path
    assert_response :success
    assert_select "title", text: "Treballadors | FitxaCAE Admin"
    assert_select "h1", text: "Treballadors"
    assert_select "table"
    assert_select "button.btn[type='submit'][data-submitting-label='Filtrant...']"
    assert_no_match "Horari", response.body

    get new_admin_employee_path
    assert_response :success
    assert_select "title", text: "Nou treballador | FitxaCAE Admin"
    assert_select "form"
    assert_select "button[type='submit'][data-submitting-label='Desant...']"
    assert_no_match "Horari", response.body

    get admin_reports_path
    assert_response :success
    assert_select "title", text: "Informes | FitxaCAE Admin"
    assert_select "h1", text: "Informes de fitxatges"
    assert_select "a[href='#']", 0
    assert_no_match "Balanç", response.body
    assert_no_match "Incidències", response.body

    get admin_corrections_path
    assert_response :success
    assert_select "title", text: "Correccions | FitxaCAE Admin"
    assert_select "table"
    assert_select "button[type='submit'][data-submitting-label='Filtrant...']"
  end

  test "no-op actions redirect to their list screens" do
    log_in_employee

    post clock_out_path
    assert_redirected_to root_path

    assert_difference "SwipeCorrection.count", 1 do
      post corrections_path, params: {
        date: Date.current.iso8601,
        requested_swipes: [ { kind: "exit", time: "17:00" } ],
        note: "Sortida oblidada"
      }
    end
    assert_redirected_to corrections_path

    log_in_manager

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
          { "kind" => "exit", "hour" => Time.current.strftime("%H:%M:%S") }
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
    assert_select "title", text: "No s'ha pogut carregar | FitxaCAE"
    assert_no_match "&amp;#", response.body
    assert_select "h1", text: "No s'ha pogut carregar"
    assert_select ".employee-nav", 0
    assert_no_match "connexió", response.body
    assert_no_match "sincron", response.body
  end
end
