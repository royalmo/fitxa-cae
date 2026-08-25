require "test_helper"

class Admin::SwipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders a full selected month without skipping empty days" do
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 16, 0), metadata: "employee_portal")

    get admin_swipes_path, params: { employee_id: employee.id, month: "7", year: "2026" }

    assert_response :success
    assert_select "h1", text: "Fitxatges"
    assert_select "a.btn[href='#{admin_reports_path(month: 7, year: 2026, report_scope: "person", employee_id: employee.id)}']", text: "Exportar" do
      assert_select "svg.icon"
    end
    assert_select "h2", text: "Filtres", count: 0
    assert_select "legend", text: "Buscar per:"
    assert_select "input[name='search_mode'][value='person'][checked='checked']"
    assert_select "input[name='search_mode'][value='category']"
    assert_select "label[for='admin_swipes_search_mode_person']", text: "Persona"
    assert_select "label[for='admin_swipes_search_mode_category']", text: "Categoria"
    assert_select "input[name='employee_id'][value='#{employee.id}']"
    assert_select "input[name='employee_query'][value='Clara Pons']"
    assert_select ".admin-employee-search[data-employee-search-url-value='#{admin_employee_search_path}']"
    assert_select "select[name='month'] option[selected][value='7']"
    assert_select "select[name='year'] option[selected][value='2026']"
    assert_select "form[action='#{admin_swipes_path}'] button[type='submit']", 0
    assert_select "input[type='month']", 0
    assert_select "thead th", text: "Estat", count: 0
    assert_select "thead th:nth-child(4)", text: "Accions"
    assert_select "tbody tr", count: 31
    assert_match "8 h 00 min", response.body
    assert_match "Sense fitxatges", response.body
    assert_select "a.admin-row-action[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-01")}'][aria-label='Crear fitxatges el 1/7/2026'] svg.icon"
    assert_select "a.admin-row-action[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-02")}'][aria-label='Editar fitxatges el 2/7/2026'] svg.icon"
  end

  test "renders pending correction review actions with confirmation modals" do
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    invalidated_entry = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      requester_comments: "Oblit de fitxatge d'entrada demo 13",
      details: {
        "invalidated_swipe_ids" => [ invalidated_entry.id ],
        "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ]
      }
    )
    validator = create_manager(email: "validator.swipes@example.test")
    approved_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      validator: validator,
      day: Date.new(2026, 7, 2),
      requester_comments: "Correcció aprovada anterior.",
      validator_comments: "Correcte.",
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      }
    )
    rejected_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :rejected,
      validator: validator,
      day: Date.new(2026, 7, 2),
      requester_comments: "Correcció rebutjada anterior.",
      validator_comments: "No procedeix.",
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )

    get admin_swipes_path, params: { employee_id: employee.id, month: "7", year: "2026" }

    assert_response :success
    assert_select "a.admin-row-action[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-02")}']", count: 0

    approve_modal_id = "admin_correction_approve_modal_#{correction.id}"
    reject_modal_id = "admin_correction_reject_modal_#{correction.id}"
    day_corrections_modal_id = "admin_swipes_day_corrections_modal_#{employee.id}_2026-07-02"
    history_button = css_select("button.admin-row-action[data-bs-target='##{day_corrections_modal_id}']").first
    assert history_button
    day_row = Capybara.string(history_button.ancestors("tr").first.to_html)
    assert_equal [
      "Veure correccions del 2/7/2026",
      "Aprovar correcció del 2/7/2026",
      "Rebutjar correcció del 2/7/2026",
      "Editar"
    ], day_row.all(".admin-row-action").map { |action| action["aria-label"] }
    assert day_row.has_css?("button.admin-row-action.btn-outline-secondary[data-bs-toggle='modal'][data-bs-target='##{day_corrections_modal_id}'] svg.icon")
    assert_select "button.admin-row-action.btn-outline-success[data-bs-toggle='modal'][data-bs-target='##{approve_modal_id}'][aria-label='Aprovar correcció del 2/7/2026'] svg.icon"
    assert_select "button.admin-row-action.btn-outline-danger[data-bs-toggle='modal'][data-bs-target='##{reject_modal_id}'][aria-label='Rebutjar correcció del 2/7/2026'] svg.icon"
    assert_select "a.admin-row-action[href='#{edit_admin_correction_path(correction)}'][aria-label='Editar'] svg.icon"
    assert_select "#swipe_correction_approve_modal_#{correction.id}", 0
    assert_select "#admin_swipes_day_corrections_modal_#{employee.id}_2026-07-03", 0

    assert_select "##{day_corrections_modal_id}.modal.fade[aria-labelledby='#{day_corrections_modal_id}_label']" do
      assert_select "h2##{day_corrections_modal_id}_label", text: "Correccions del 2 Juliol 2026"
      assert_select ".admin-swipes-day-correction-item", count: 3
      assert_select ".badge", count: 0
      assert_select ".admin-swipes-day-correction-status", text: "Pendent"
      assert_select ".admin-swipes-day-correction-status", text: "Aprovada"
      assert_select ".admin-swipes-day-correction-status", text: "Rebutjada"
      assert_select ".admin-correction-change-item.is-invalidate.is-entry", text: "08:00"
      assert_select ".admin-correction-change-item.is-requested.is-entry", text: "08:05"
      assert_select ".admin-correction-change-item.is-requested.is-exit", text: "17:00"
      assert_select ".modal-body", text: /Oblit de fitxatge d'entrada demo 13/, count: 0
      assert_select ".modal-body", text: /Correcció aprovada anterior/, count: 0
      assert_select ".modal-body", text: /Correcció rebutjada anterior/, count: 0
      assert_select ".modal-body", text: /fa menys d'1 minut/, count: 0
      assert_select "a.btn[href='#{admin_correction_path(correction)}'][aria-label='Veure']", text: "Veure" do
        assert_select "svg.icon"
      end
      assert_select "a.btn[href='#{admin_correction_path(approved_correction)}'][aria-label='Veure']", text: "Veure" do
        assert_select "svg.icon"
      end
      assert_select "a.btn[href='#{admin_correction_path(rejected_correction)}'][aria-label='Veure']", text: "Veure" do
        assert_select "svg.icon"
      end
    end

    assert_select "##{approve_modal_id}.modal.fade[aria-labelledby='#{approve_modal_id}_label']" do
      assert_select "h2##{approve_modal_id}_label", text: "Aprovar correcció"
      assert_select ".modal-body", text: /Vols aprovar la següent correcció horària/
      assert_select ".admin-correction-review-person", text: /Clara Pons/
      assert_select "dt", text: "Dia sol·licitat"
      assert_select "dd", text: "2 Juliol 2026"
      assert_select ".modal-body", text: /Hora sol·licitada:/, count: 0
      assert_select "dt", text: "Sol·licitud"
      assert_select ".admin-swipes-review-pills", 0
      assert_select ".admin-correction-change-item.is-invalidate.is-entry", text: "08:00"
      assert_select ".admin-correction-change-item.is-requested.is-exit", text: "17:00"
      assert_select "dt", text: "Comentaris"
      assert_select "dd", text: "Oblit de fitxatge d'entrada demo 13"
      assert_select "form[action='#{approve_admin_correction_path(correction)}'][method='post']" do
        assert_select "label[for='#{approve_modal_id}_validator_comments']", text: "Comentaris de RRHH"
        assert_select "textarea##{approve_modal_id}_validator_comments[name='validator_comments']"
        assert_select "button[type='submit'][data-submitting-label='Aprovant...']", text: "Aprovar"
      end
    end

    assert_select "##{reject_modal_id}.modal.fade[aria-labelledby='#{reject_modal_id}_label']" do
      assert_select "h2##{reject_modal_id}_label", text: "Rebutjar correcció"
      assert_select ".modal-body", text: /Vols rebutjar la següent correcció horària/
      assert_select "form[action='#{reject_admin_correction_path(correction)}'][method='post']" do
        assert_select "label[for='#{reject_modal_id}_validator_comments']", text: "Comentaris de RRHH"
        assert_select "textarea##{reject_modal_id}_validator_comments[name='validator_comments']"
        assert_select "button[type='submit'][data-submitting-label='Rebutjant...']", text: "Rebutjar"
      end
    end
  end

  test "renders no employee by default" do
    create_employee

    travel_to Time.zone.local(2026, 7, 26, 12, 0) do
      get admin_swipes_path
    end

    assert_response :success
    assert_select "a.btn[href='#{admin_reports_path(month: 7, year: 2026)}']", text: "Exportar"
    assert_select "input[name='search_mode'][value='person'][checked='checked']"
    assert_select "input[name='employee_id'][value='']", 1
    assert_select "input[name='employee_query'][placeholder='Cerca per nom, DNI, correu o telèfon']", 1
    assert_select "select[name='category'] option", text: "Selecciona una categoria"
    assert_select "select[name='month'] option[selected][value='7']"
    assert_select "select[name='year'] option[selected][value='2026']"
    assert_select ".admin-calendar-empty .icon", 1
    assert_select ".admin-calendar-empty p.small", text: "Selecciona una persona per veure els fitxatges."
    assert_select "tbody tr", 0
  end

  test "filters category erroneous swipes without empty days or today's swipes" do
    odd_employee = create_employee(first_name: "Jana", last_name: "Imparell", national_id: valid_dni(42_300_001))
    today_employee = create_employee(first_name: "Ona", last_name: "Avui", national_id: valid_dni(42_300_002))
    even_employee = create_employee(first_name: "Clara", last_name: "Parell", national_id: valid_dni(42_300_003))
    odd_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 15, 9, 0), metadata: "employee_portal")
    today_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 25, 9, 0), metadata: "employee_portal")
    even_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 17, 9, 0), metadata: "employee_portal")
    even_employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 8, 17, 17, 0), metadata: "employee_portal")

    travel_to Time.zone.local(2026, 8, 25, 12, 0) do
      get admin_swipes_path, params: { search_mode: "category", category: "erroneous_swipes", month: "8", year: "2026" }
    end

    assert_response :success
    assert_select "input[name='search_mode'][value='category'][checked='checked']"
    assert_select "[data-swipe-search-mode-target='personPanel'][hidden]"
    assert_select "[data-swipe-search-mode-target='categoryPanel'][hidden]", 0
    assert_select "select[name='category'] option[value='erroneous_swipes'][selected]", text: "Fitxatges erronis"
    assert_select ".admin-result-count", text: "Mostrant 1-1 de 1"
    assert_select "thead th:first-child", text: "Persona"
    assert_select "tbody tr", count: 1
    assert_select "td.admin-swipes-hours-cell.is-odd", text: "0 h 00 min"
    assert_select "td.admin-swipes-hours-cell.is-pending", count: 0
    assert_match "Jana Imparell", response.body
    assert_no_match "Ona Avui", response.body
    assert_no_match "Clara Parell", response.body
    assert_select "a.admin-row-action[href='#{new_admin_correction_path(employee_id: odd_employee.id, day: "2026-08-15")}'][aria-label='Editar fitxatges el 15/8/2026'] svg.icon"
  end

  test "filters category pending corrections" do
    employee = create_employee(first_name: "Berta", last_name: "Pendent", national_id: valid_dni(42_300_004))
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 22),
      requester_comments: "Cal afegir una entrada.",
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "09:00:00" } ]
      }
    )
    employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 23),
      requester_comments: "Ja revisada.",
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )

    get admin_swipes_path, params: { search_mode: "category", category: "pending_corrections", month: "7", year: "2026" }

    assert_response :success
    assert_select "select[name='category'] option[value='pending_corrections'][selected]", text: "Fitxatges amb correcció pendent"
    assert_select ".admin-result-count", text: "Mostrant 1-1 de 1"
    assert_select "tbody tr", count: 1
    assert_select "td.admin-swipes-hours-cell.is-pending", text: "0 h 00 min"
    assert_select "td.admin-swipes-hours-cell.is-odd", count: 0
    assert_match "Berta Pendent", response.body
    assert_no_match "23 Juliol 2026", response.body
    assert_select "button.admin-row-action.btn-outline-success[data-bs-target='#admin_correction_approve_modal_#{correction.id}'][aria-label='Aprovar correcció del 22/7/2026'] svg.icon"
    assert_select "a.admin-row-action[href='#{edit_admin_correction_path(correction)}'][aria-label='Editar'] svg.icon"
  end

  test "paginates category day results" do
    employees = 21.times.map do |index|
      create_employee(first_name: "Usuari", last_name: format("Erroni %02d", index + 1), national_id: valid_dni(42_400_000 + index))
    end
    employees.each_with_index do |employee, index|
      employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, index + 1, 9, 0), metadata: "employee_portal")
    end

    travel_to Time.zone.local(2026, 8, 25, 12, 0) do
      get admin_swipes_path, params: { search_mode: "category", category: "erroneous_swipes", month: "7", year: "2026" }
    end

    assert_response :success
    assert_select "tbody tr", count: 20
    assert_select ".admin-result-count", text: "Mostrant 1-20 de 21"
    assert_select ".admin-page-status", text: "Pàgina 1 de 2"
    assert_match "Usuari Erroni 01", response.body
    assert_match "Usuari Erroni 20", response.body
    assert_no_match "Usuari Erroni 21", response.body

    travel_to Time.zone.local(2026, 8, 25, 12, 0) do
      get admin_swipes_path, params: { search_mode: "category", category: "erroneous_swipes", month: "7", year: "2026", page: "2" }
    end

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select ".admin-result-count", text: "Mostrant 21-21 de 21"
    assert_select ".admin-page-status", text: "Pàgina 2 de 2"
    assert_match "Usuari Erroni 21", response.body
  end

  test "falls back to the current period for invalid params" do
    create_employee

    travel_to Time.zone.local(2026, 7, 26, 12, 0) do
      get admin_swipes_path, params: { month: "bad", year: "bad" }
    end

    assert_response :success
    assert_select "select[name='month'] option[selected][value='7']"
    assert_select "select[name='year'] option[selected][value='2026']"
  end

  test "keeps legacy month params and includes previous selected years" do
    employee = create_employee(first_name: "Clara", last_name: "Pons")

    get admin_swipes_path, params: { employee_id: employee.id, month: "2025-12" }

    assert_response :success
    assert_select "select[name='month'] option[selected][value='12']"
    assert_select "select[name='year'] option[selected][value='2025']"
    assert_select "select[name='year'] option[value='2025']"
    assert_select "select[name='year'] option[value='2026']"
  end
end
