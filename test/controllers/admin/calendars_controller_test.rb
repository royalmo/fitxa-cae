require "test_helper"

class Admin::CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders no calendar by default" do
    create_employee(first_name: "Jana", last_name: "Sol")

    get admin_calendars_path

    assert_response :success
    assert_select "input[name='employee_id'][value='']", 1
    assert_select "input[name='employee_query'][placeholder='Cerca per nom, DNI, correu o telèfon']", 1
    assert_select ".admin-employee-search[data-employee-search-url-value='#{admin_employee_search_path}']"
    assert_select ".admin-calendar-legend li", text: "Fitxatges"
    assert_select ".admin-calendar-legend li", text: "Pendent"
    assert_select ".admin-calendar-legend li", text: "Erroni"
    assert_select "form[action='#{admin_calendars_path}'] button[type='submit']", 0
    assert_select ".card h2", text: "Filtres", count: 0
    assert_select ".admin-calendar-grid", 0
    assert_select ".admin-calendar-empty .icon", 1
    assert_select ".admin-calendar-empty p.small", text: "Selecciona una treballadora per veure el calendari."
  end

  test "renders year calendar with status colors and correction links" do
    employee = create_employee(first_name: "Jana", last_name: "Sol")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 1, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 1, 2, 16, 25), metadata: "employee_portal")
    pending_correction = employee.swipe_corrections.create!(requester: employee, status: :pending, day: Date.new(2026, 1, 3))
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 1, 4, 8, 0), metadata: "employee_portal")

    travel_to Time.zone.local(2026, 7, 25, 10, 0) do
      get admin_calendars_path, params: { employee_id: employee.id, year: "2026" }
    end

    assert_response :success
    assert_select "h1", text: "Calendaris"
    assert_select "input[name='employee_id'][value='#{employee.id}']"
    assert_select "input[name='employee_query'][value='Jana Sol']"
    assert_select "input[type='hidden'][name='year'][value='2026']"
    assert_select "button[aria-label='Any anterior'][data-calendar-controls-delta-param='-1']"
    assert_select "button[aria-label='Any següent'][data-calendar-controls-delta-param='1']"
    assert_select ".admin-calendar-year-value", text: "2026"
    assert_select ".admin-list-loading-lg .admin-list-loading-spinner"
    assert_select ".admin-list-loading-lg .admin-list-loading-label", text: "Carregant calendari..."
    assert_select ".row[data-controller='bootstrap-popover'] .admin-calendar-grid"
    assert_calendar_day_popover(
      ".admin-calendar-day.is-success-2",
      text: "2",
      content: "2 fitxatges, 8 h 25 min treballats.",
      action: "Corregir",
      path: new_admin_correction_path(employee_id: employee.id, day: "2026-01-02")
    )
    assert_calendar_day_popover(
      ".admin-calendar-day.is-warning",
      text: "3",
      content: "Hi ha una correcció pendent de validació.",
      action: "Revisar",
      path: edit_admin_correction_path(pending_correction)
    )
    assert_calendar_day_popover(
      ".admin-calendar-day.is-danger",
      text: "4",
      content: "Nombre imparell de fitxatges.",
      action: "Corregir",
      path: new_admin_correction_path(employee_id: employee.id, day: "2026-01-04")
    )
    assert_calendar_day_popover(
      ".admin-calendar-day.is-empty[data-bs-title='#{I18n.l(Date.new(2026, 1, 5), format: :long)}']",
      text: "5",
      content: "Sense fitxatges.",
      action: "Crear",
      path: new_admin_correction_path(employee_id: employee.id, day: "2026-01-05")
    )
    assert_select "a.admin-calendar-day", 0
  end

  test "current odd day is not marked danger and future days are not clickable" do
    employee = create_employee(first_name: "Jana", last_name: "Sol")
    today = Date.new(2026, 7, 25)
    tomorrow = today + 1.day
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 25, 8, 0), metadata: "employee_portal")

    travel_to Time.zone.local(2026, 7, 25, 10, 0) do
      get admin_calendars_path, params: { employee_id: employee.id, year: "2026" }
    end

    assert_response :success
    assert_select "button.admin-calendar-day.is-success-1[aria-label='#{I18n.l(today, format: :long)} · 1 fitxatge']", text: "25"
    assert_select "button.admin-calendar-day.is-danger[aria-label='#{I18n.l(today, format: :long)} · 1 fitxatge']", 0
    assert_select "span.admin-calendar-day.is-empty.is-future[aria-label='#{I18n.l(tomorrow, format: :long)}']", text: "26"
    assert_select "button.admin-calendar-day[aria-label='#{I18n.l(tomorrow, format: :long)}']", 0
  end

  test "falls back to the current year for invalid year params" do
    create_employee

    get admin_calendars_path, params: { year: "bad" }

    assert_response :success
    assert_select "input[type='hidden'][name='year'][value='#{Time.zone.today.year}']"
  end

  test "employee search matches inactive employees by name and contact fields" do
    employee = create_employee(
      first_name: "Mireia",
      last_name: "Bosch",
      national_id: valid_dni(41_000_001),
      email: "mireia.bosch@example.test",
      phone: "+34 600 111 222",
      active: false
    )
    create_employee(
      first_name: "Pau",
      last_name: "Vila",
      national_id: valid_dni(41_000_002),
      email: "pau.vila@example.test",
      phone: "+34 600 333 444"
    )

    get admin_employee_search_path, params: { q: "Mireia" }

    assert_response :success
    assert_select ".admin-employee-search-result[data-employee-search-id-param='#{employee.id}']",
      text: /Mireia Bosch\s+-\s+#{employee.national_id}/
    assert_no_match "Pau Vila", response.body
    assert_no_match employee.email, response.body
    assert_no_match employee.phone, response.body

    get admin_employee_search_path, params: { q: employee.national_id.delete_suffix(employee.national_id.last) }

    assert_response :success
    assert_select ".admin-employee-search-result[data-employee-search-id-param='#{employee.id}']"

    get admin_employee_search_path, params: { q: "600111222" }

    assert_response :success
    assert_select ".admin-employee-search-result[data-employee-search-id-param='#{employee.id}']",
      text: /Mireia Bosch\s+-\s+#{employee.national_id}/
    assert_no_match "Pau Vila", response.body
    assert_no_match employee.email, response.body
    assert_no_match employee.phone, response.body

    get admin_employee_search_path, params: { q: employee.email }

    assert_response :success
    assert_select ".admin-employee-search-result[data-employee-search-id-param='#{employee.id}']"
    assert_no_match employee.email, response.body
    assert_no_match employee.phone, response.body
  end

  private

  def assert_calendar_day_popover(selector, text:, content:, action:, path:)
    assert_select "#{selector}[type='button'][data-bs-toggle='popover'][data-bootstrap-popover-target='trigger']", text: text do |days|
      popover_content = days.first["data-bs-content"]
      assert_includes popover_content, content
      assert_includes popover_content, action
      assert_includes popover_content, path
      assert_includes popover_content, "admin-calendar-popover-action"
      assert_includes popover_content, "<svg"
    end
  end
end
