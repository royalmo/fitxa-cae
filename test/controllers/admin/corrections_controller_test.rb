require "test_helper"

class Admin::CorrectionsControllerTest < ActionDispatch::IntegrationTest
  test "lists persisted corrections" do
    log_in_manager
    employee = create_employee(first_name: "Laia", last_name: "Font")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ]
      }
    )

    get admin_corrections_path

    assert_response :success
    assert_match "Laia Font", response.body
    assert_match "Correcció de fitxatge", response.body
    assert_match "Sortida 17:00", response.body
    assert_select "[data-controller='list-loading']"
    assert_select "h2", text: "Filtres", count: 0
    assert_select ".admin-result-count[data-list-loading-target='results']",
      text: "Mostrant 1-#{[ SwipeCorrection.count, 20 ].min} de #{SwipeCorrection.count}"
    assert_select ".text-center .admin-result-count",
      text: "Mostrant 1-#{[ SwipeCorrection.count, 20 ].min} de #{SwipeCorrection.count}"
    assert_select "form.admin-corrections-filter-form[action='#{admin_corrections_path}'][method='get']" do
      assert_select ".admin-employee-search[data-employee-search-url-value='#{admin_employee_search_path}']" do
        assert_select "input[type='hidden'][name='employee_id'][value='']"
        assert_select "input[name='employee_query'][placeholder='Cerca per nom, DNI, correu o telèfon']"
        assert_select "button[type='button'][aria-label='Tots els treballadors'][data-action='employee-search#clear'] svg.icon"
      end
      assert_select "select[name='employee_id']", count: 0
      assert_select "select[name='status']", count: 0
      assert_select "input[type='radio'][name='status'][value=''][checked='checked'][autocomplete='off'] + label", text: "Totes"
      assert_select "input[type='radio'][name='status'][value='pending'][autocomplete='off'] + label svg.admin-badge-icon + span", text: "Pendents"
      assert_select "input[type='radio'][name='status'][value='approved'][autocomplete='off'] + label svg.admin-badge-icon + span", text: "Aprovades"
      assert_select "input[type='radio'][name='status'][value='rejected'][autocomplete='off'] + label svg.admin-badge-icon + span", text: "Rebutjades"
      assert_select ".admin-corrections-period-label:not(.input-group-text)", text: /Correccions de dies en/
      assert_select ".admin-corrections-period-label span[aria-hidden='true']", text: "·"
      assert_select "select[name='month'] option[selected][value='']", text: "Tots els mesos"
      assert_select "select[name='year'] option[selected][value='']", text: "Tots els anys"
      assert_select "button[type='submit'][data-submitting-label='Filtrant...']", count: 0
    end
    assert_select "button.btn.admin-row-action[aria-label='Aprovar'][data-submitting-label='Aprovant...'] svg.icon"
    assert_select "button.btn.admin-row-action[aria-label='Rebutjar'][data-submitting-label='Rebutjant...'] svg.icon"
    assert_select ".badge.text-bg-warning svg.admin-badge-icon"
  end

  test "filters corrections by status employee and period" do
    log_in_manager
    visible_employee = create_employee(first_name: "Nil", last_name: "Prats", national_id: valid_dni(42_200_001))
    hidden_employee = create_employee(first_name: "Ona", last_name: "Serra", national_id: valid_dni(42_200_002))
    visible_employee.swipe_corrections.create!(
      requester: visible_employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )
    hidden_employee.swipe_corrections.create!(
      requester: hidden_employee,
      status: :pending,
      day: Date.new(2026, 8, 4)
    )
    hidden_employee.swipe_corrections.create!(
      requester: hidden_employee,
      status: :approved,
      day: Date.new(2026, 7, 4)
    )

    get admin_corrections_path, params: {
      status: "pending",
      employee_id: visible_employee.id,
      month: "7",
      year: "2026"
    }

    assert_response :success
    row_text = css_select("tbody tr").map { |row| row.text.squish }.join(" ")
    assert_match "Nil Prats", row_text
    assert_no_match "Ona Serra", row_text
    assert_select "input[name='employee_id'][value='#{visible_employee.id}']"
    assert_select "input[name='employee_query'][value='Nil Prats']"
    assert_select "input[type='radio'][name='status'][value='pending'][checked='checked'] + label", text: "Pendents"
    assert_select "select[name='month'] option[selected][value='7']"
    assert_select "select[name='year'] option[selected][value='2026']"
  end

  test "filters corrections by month across all years" do
    log_in_manager
    july_employee = create_employee(first_name: "Juliol", last_name: "Prat", national_id: valid_dni(42_200_003))
    august_employee = create_employee(first_name: "Agost", last_name: "Serra", national_id: valid_dni(42_200_004))
    july_employee.swipe_corrections.create!(requester: july_employee, status: :pending, day: Date.new(2026, 7, 4))
    august_employee.swipe_corrections.create!(requester: august_employee, status: :pending, day: Date.new(2026, 8, 4))

    get admin_corrections_path, params: { month: "7" }

    assert_response :success
    row_text = css_select("tbody tr").map { |row| row.text.squish }.join(" ")
    assert_match "Juliol Prat", row_text
    assert_no_match "Agost Serra", row_text
    assert_select "select[name='month'] option[selected][value='7']"
    assert_select "select[name='year'] option[selected][value='']", text: "Tots els anys"
  end

  test "highlights corrections for requested day" do
    log_in_manager
    employee = create_employee(first_name: "Aina", last_name: "Martinez", national_id: valid_dni(42_200_005))
    employee.swipe_corrections.create!(requester: employee, status: :approved, day: Date.new(2026, 7, 4))
    employee.swipe_corrections.create!(requester: employee, status: :rejected, day: Date.new(2026, 7, 4))
    employee.swipe_corrections.create!(requester: employee, status: :approved, day: Date.new(2026, 7, 5))

    get admin_corrections_path,
      params: {
        employee_id: employee.id,
        month: "7",
        year: "2026",
        highlight_day: "2026-07-04"
      }

    assert_response :success
    assert_select "[data-controller='correction-highlight']"
    assert_select "tr.admin-correction-row", 3
    assert_select "tr.admin-correction-row.is-highlighted[data-correction-day='2026-07-04'][data-correction-highlight-target='row'][tabindex='-1']", 2
    assert_select "tr.admin-correction-row.is-highlighted[data-correction-day='2026-07-05']", 0
  end

  test "new correction form waits for employee and day before showing swipe controls" do
    log_in_manager

    get new_admin_correction_path

    assert_response :success
    assert_select "form[action='#{admin_corrections_path}'][data-controller='correction-form'][data-correction-form-update-url-value='true']" do
      assert_select ".admin-employee-search[data-controller='employee-search'][data-employee-search-auto-submit-value='false']"
      assert_select "select[name='swipe_correction[employee_id]']", 0
      assert_select "input[type='hidden'][name='swipe_correction[employee_id]'][value=''][data-correction-form-target='employeeId']"
      assert_select "input[type='date'][name='swipe_correction[day]'][data-correction-form-target='date']"
      assert_select "[data-correction-form-target='emptyPrompt']", text: "Selecciona una treballadora i un dia per veure els fitxatges."
      assert_select "[data-correction-form-target='emptyPrompt'][hidden]", 0
      assert_select "[data-correction-form-target='formContent'][hidden]"
      assert_select "[data-correction-form-target='submitActions'][hidden]"
      assert_select "button[type='submit'][data-submitting-label='Creant i aprovant...']", text: "Crear i aprovar correcció"
    end
  end

  test "new correction form shows swipe controls when employee and day are selected" do
    log_in_manager
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 40), metadata: "employee_portal")

    get new_admin_correction_path, params: { employee_id: employee.id, day: "2026-07-04" }

    assert_response :success
    assert_no_match "Ja hi ha una correcció pendent per aquest dia.", response.body
    assert_select "input[type='hidden'][name='swipe_correction[employee_id]'][value='#{employee.id}']"
    assert_select "input[name='employee_query'][value='Clara Pons']"
    assert_select "input[type='date'][name='swipe_correction[day]'][value='2026-07-04'][disabled]", 0
    assert_select "[data-correction-form-target='formContent'][hidden]", 0
    assert_select "[data-correction-form-target='submitActions'][hidden]", 0
    assert_select ".correction-swipe-column[data-kind='entry'] .correction-existing-swipe", text: /08:40/
  end

  test "new correction form shows existing pending correction prompt instead of swipe controls" do
    log_in_manager
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )

    get new_admin_correction_path, params: { employee_id: employee.id, day: "2026-07-04" }

    assert_response :success
    assert_select "[data-correction-form-target='emptyPrompt'][hidden]"
    assert_select "[data-correction-form-target='existingCorrectionPrompt']:not([hidden])" do
      assert_select ".admin-existing-correction-prompt", text: /Aquest dia ja té una correcció/
      assert_select ".admin-existing-correction-prompt", text: /Clara Pons/
      assert_select "a.btn[href='#{admin_correction_path(correction)}']", text: "Veure"
      assert_select "a.btn[href='#{edit_admin_correction_path(correction)}']", text: "Editar"
      assert_select "a.btn[data-turbo-method='post'][href='#{approve_admin_correction_path(correction)}']", text: "Aprovar"
      assert_select "a.btn[data-turbo-method='post'][href='#{reject_admin_correction_path(correction)}']", text: "Rebutjar"
    end
    assert_select "[data-correction-form-target='formContent'][hidden]"
    assert_select "[data-correction-form-target='submitActions'][hidden]"
    assert_select "button.correction-requested-swipe-add", 2
  end

  test "new correction form prefers pending correction over reviewed correction for the same day" do
    log_in_manager
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      created_at: Time.zone.local(2026, 7, 4, 9, 0)
    )
    approved_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 4),
      created_at: Time.zone.local(2026, 7, 4, 10, 0)
    )

    get new_admin_correction_path, params: { employee_id: employee.id, day: "2026-07-04" }

    assert_response :success
    assert_select ".admin-existing-correction-prompt", text: /Aquest dia ja té una correcció/
    assert_select ".alert.alert-info.alert-dismissible", 0
    assert_select "a.btn[href='#{admin_correction_path(pending_correction)}']", text: "Veure"
    assert_select "a.btn[href='#{edit_admin_correction_path(pending_correction)}']", text: "Editar"
    assert_select "a.alert-link", 0
    assert_select "[data-correction-form-target='formContent'][hidden]"
    assert_select "[data-correction-form-target='submitActions'][hidden]"
    assert_no_match admin_correction_path(approved_correction), response.body
  end

  test "new correction form shows reviewed correction banner and keeps form available" do
    log_in_manager
    employee = create_employee
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 40), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 4)
    )

    get new_admin_correction_path, params: { employee_id: employee.id, day: "2026-07-04" }

    assert_response :success
    assert_select "[data-correction-form-target='existingCorrectionPrompt']:not([hidden])" do
      assert_select ".admin-existing-correction-prompt", 0
      assert_select ".alert.alert-info.alert-dismissible", text: /Aquest dia ja té una correcció aprovada/
      assert_select ".alert.alert-info.alert-dismissible svg.admin-existing-correction-info-icon"
      assert_select "a.alert-link[href='#{admin_corrections_path(employee_id: employee.id, month: 7, year: 2026, highlight_day: "2026-07-04")}']", text: "Veure"
      assert_select "button.btn-close[data-bs-dismiss='alert']"
      assert_select "a.btn[href='#{admin_correction_path(correction)}']", 0
      assert_select "a.btn[href='#{edit_admin_correction_path(correction)}']", 0
      assert_select "a.btn[data-turbo-method='post'][href='#{approve_admin_correction_path(correction)}']", 0
      assert_select "a.btn[data-turbo-method='post'][href='#{reject_admin_correction_path(correction)}']", 0
    end
    assert_select "[data-correction-form-target='formContent'][hidden]", 0
    assert_select "[data-correction-form-target='submitActions'][hidden]", 0
    assert_select ".correction-swipe-column[data-kind='entry'] .correction-existing-swipe", text: /08:40/
  end

  test "renders requested swipes in correction form like employee correction controls" do
    log_in_manager
    employee = create_employee
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 40), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [
          { "kind" => "entry", "hour" => "08:05:00" },
          { "kind" => "exit", "hour" => "17:30:00" }
        ]
      }
    )

    get edit_admin_correction_path(correction)

    assert_response :success
    form_text = css_select("form").first.text
    assert_no_match "Fitxatges existents", form_text
    assert_no_match "Fitxatges sol·licitats", form_text
    assert_no_match "data-correction-form-exit-icon-value", form_text
    assert_select "form[data-controller='correction-form'] .admin-correction-swipes" do
      assert_select ".correction-swipe-column[data-kind='entry'] .correction-swipe-column-header", text: "Entrades"
      assert_select ".correction-swipe-column[data-kind='exit'] .correction-swipe-column-header", text: "Sortides"
      assert_select ".correction-swipe-request-cell select", 0
      assert_select ".correction-swipe-column[data-kind='entry'] input[type='checkbox'][name='swipe_correction[invalidated_swipe_ids][]'][value='#{swipe.id}']"
      assert_select ".correction-swipe-column[data-kind='entry'] .correction-existing-swipe", text: /08:40/
      assert_select ".correction-swipe-request-cell .correction-existing-swipe.correction-requested-swipe", 2
      assert_select ".correction-swipe-column[data-kind='entry'] input[type='hidden'][name='swipe_correction[requested_swipes][][kind]'][value='entry']"
      assert_select ".correction-swipe-column[data-kind='entry'] input[type='time'][name='swipe_correction[requested_swipes][][hour]'][value='08:05']"
      assert_select ".correction-swipe-column[data-kind='exit'] input[type='time'][name='swipe_correction[requested_swipes][][hour]'][value='17:30']"
      assert_select "button.correction-requested-swipe-remove[aria-label='Eliminar fitxatge sol·licitat']", 2
      assert_select "button.correction-requested-swipe-add[data-action='correction-form#addRequestedSwipe'][data-kind='entry']", text: /Afegir entrada/
      assert_select "button.correction-requested-swipe-add[data-action='correction-form#addRequestedSwipe'][data-kind='exit']", text: /Afegir sortida/
    end
  end

  test "edit correction form keeps employee and day non editable" do
    log_in_manager
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )

    get edit_admin_correction_path(correction)

    assert_response :success
    assert_select "form[data-controller='correction-form'][data-correction-form-update-url-value='false']"
    assert_select "input[type='hidden'][name='swipe_correction[employee_id]'][value='#{employee.id}']"
    assert_select "input[name='employee_query'][value='Clara Pons'][disabled]"
    assert_select "button[data-action='employee-search#clear']", 0
    assert_select "input[type='date'][name='swipe_correction[day]'][value='2026-07-04'][disabled]"
    assert_select "input[type='hidden'][name='swipe_correction[day]'][value='2026-07-04'][data-correction-form-target='date']"
  end

  test "returns day swipes for selected admin correction employee and day" do
    log_in_manager
    employee = create_employee
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 40), metadata: "employee_portal")

    get day_admin_corrections_path, params: { employee_id: employee.id, date: "2026-07-04" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["day_allowed"]
    assert_equal [ { "id" => employee.swipes.last.id.to_s, "kind" => "entry", "time" => "08:40" } ], payload["swipes"]
  end

  test "returns existing correction prompt html for selected admin correction employee and day" do
    log_in_manager
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )

    get day_admin_corrections_path, params: { employee_id: employee.id, date: "2026-07-04" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_includes payload["existing_correction_html"], "Aquest dia ja té una correcció"
    assert_includes payload["existing_correction_html"], admin_correction_path(correction)
    assert_includes payload["existing_correction_html"], edit_admin_correction_path(correction)
    assert_includes payload["existing_correction_html"], approve_admin_correction_path(correction)
    assert_includes payload["existing_correction_html"], reject_admin_correction_path(correction)
    assert_equal true, payload["existing_correction_blocks_form"]
  end

  test "returns pending correction prompt html before reviewed correction for selected employee and day" do
    log_in_manager
    employee = create_employee
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      created_at: Time.zone.local(2026, 7, 4, 9, 0)
    )
    approved_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 4),
      created_at: Time.zone.local(2026, 7, 4, 10, 0)
    )

    get day_admin_corrections_path, params: { employee_id: employee.id, date: "2026-07-04" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_includes payload["existing_correction_html"], admin_correction_path(pending_correction)
    assert_includes payload["existing_correction_html"], edit_admin_correction_path(pending_correction)
    assert_not_includes payload["existing_correction_html"], admin_correction_path(approved_correction)
    assert_not_includes payload["existing_correction_html"], "alert-dismissible"
    assert_equal true, payload["existing_correction_blocks_form"]
  end

  test "returns compact reviewed correction prompt html for selected admin correction employee and day" do
    log_in_manager
    employee = create_employee
    employee.swipe_corrections.create!(
      requester: employee,
      status: :rejected,
      day: Date.new(2026, 7, 4)
    )

    get day_admin_corrections_path, params: { employee_id: employee.id, date: "2026-07-04" }

    assert_response :success
    payload = JSON.parse(response.body)
    prompt = Capybara.string(payload["existing_correction_html"])
    assert_includes payload["existing_correction_html"], "Aquest dia ja té una correcció rebutjada"
    assert prompt.has_css?("svg.admin-existing-correction-info-icon")
    assert prompt.has_css?("a.alert-link[href='#{admin_corrections_path(employee_id: employee.id, month: 7, year: 2026, highlight_day: "2026-07-04")}']", text: "Veure")
    assert_includes payload["existing_correction_html"], "alert-dismissible"
    assert_not_includes payload["existing_correction_html"], "admin-existing-correction-prompt"
    assert_equal false, payload["existing_correction_blocks_form"]
  end

  test "does not return day swipes without employee and day" do
    log_in_manager

    get day_admin_corrections_path

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal false, payload["day_allowed"]
    assert_equal [], payload["swipes"]
  end

  test "does not create a manager correction when one pending correction already exists for the day" do
    log_in_manager
    employee = create_employee
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )

    assert_no_difference "SwipeCorrection.count" do
      post admin_corrections_path, params: {
        swipe_correction: {
          employee_id: employee.id,
          day: "2026-07-04",
          requester_comments: "Duplicada",
          requested_swipes: [
            { kind: "entry", hour: "08:00" }
          ]
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Ja hi ha una correcció per aquest treballador i dia/
    assert_select "[data-correction-form-target='existingCorrectionPrompt']:not([hidden])"
  end

  test "creates and approves a manager correction when only reviewed corrections exist for the day" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 4)
    )

    assert_difference "SwipeCorrection.count", 1 do
      assert_difference -> { employee.swipes.count }, 1 do
        post admin_corrections_path, params: {
          swipe_correction: {
            employee_id: employee.id,
            day: "2026-07-04",
            requester_comments: "Nova sol·licitud",
            requested_swipes: [
              { kind: "entry", hour: "08:00" }
            ]
          }
        }
      end
    end

    correction = SwipeCorrection.find_by!(requester: manager, requester_comments: "Nova sol·licitud")
    assert_redirected_to admin_correction_path(correction)
    assert_predicate correction, :approved?
    assert_equal manager, correction.requester
    assert_equal manager, correction.validator
    assert_equal employee, correction.employee
    assert_equal "Nova sol·licitud", correction.requester_comments
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{correction.id}", kind: "entry").exists?
  end

  test "creates and approves a manager correction with requested swipes" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee

    assert_difference "SwipeCorrection.count", 1 do
      assert_difference -> { employee.swipes.count }, 2 do
        post admin_corrections_path, params: {
          swipe_correction: {
            employee_id: employee.id,
            day: "2026-07-04",
            requester_comments: "Alta manual",
            requested_swipes: [
              { kind: "entry", hour: "08:00" },
              { kind: "exit", hour: "16:30" }
            ]
          }
        }
      end
    end

    correction = SwipeCorrection.find_by!(requester: manager, requester_comments: "Alta manual")
    assert_redirected_to admin_correction_path(correction)
    assert_predicate correction, :approved?
    assert_equal manager, correction.requester
    assert_equal manager, correction.validator
    assert_equal "Alta manual", correction.requester_comments
    assert_equal [
      { "kind" => "entry", "hour" => "08:00:00" },
      { "kind" => "exit", "hour" => "16:30:00" }
    ], correction.details.fetch("requested_swipes")
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{correction.id}", kind: "entry", swipe_at: Time.zone.local(2026, 7, 4, 8, 0)).exists?
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{correction.id}", kind: "exit", swipe_at: Time.zone.local(2026, 7, 4, 16, 30)).exists?
  end

  test "updates a correction and selected swipes to invalidate" do
    log_in_manager
    employee = create_employee
    other_employee = create_employee
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 45), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )

    patch admin_correction_path(correction), params: {
      swipe_correction: {
        employee_id: other_employee.id,
        day: "2026-07-05",
        requester_comments: "Revisat",
        invalidated_swipe_ids: [ swipe.id ],
        requested_swipes: {
          "0" => { kind: "entry", hour: "08:00" }
        }
      }
    }

    assert_redirected_to admin_correction_path(correction)
    correction.reload
    assert_equal "Revisat", correction.requester_comments
    assert_equal employee, correction.employee
    assert_equal Date.new(2026, 7, 4), correction.day
    assert_equal [ swipe.id.to_s ], correction.details.fetch("invalidated_swipe_ids")
    assert_equal [ { "kind" => "entry", "hour" => "08:00:00" } ], correction.details.fetch("requested_swipes")
  end

  test "approves a pending correction and applies requested swipes" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    old_swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 45), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: {
        "invalidated_swipe_ids" => [ old_swipe.id ],
        "requested_swipes" => [
          { "kind" => "entry", "hour" => "08:05:00" },
          { "kind" => "exit", "hour" => "17:00:00" }
        ]
      }
    )

    assert_difference "employee.swipes.count", 2 do
      post approve_admin_correction_path(correction)
    end

    assert_redirected_to admin_corrections_path
    correction.reload
    assert_predicate correction, :approved?
    assert_equal manager, correction.validator
    assert_predicate old_swipe.reload, :removed?
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{correction.id}").exists?(kind: "exit")
    assert employee.swipes.where(swipe_at: Time.zone.local(2026, 7, 4, 17, 0)).exists?
  end

  test "rejects a pending correction without changing swipes" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )

    assert_no_difference "employee.swipes.count" do
      post reject_admin_correction_path(correction)
    end

    assert_redirected_to admin_corrections_path
    correction.reload
    assert_predicate correction, :rejected?
    assert_equal manager, correction.validator
  end

  test "review redirects back to referrer when present" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )
    referrer = admin_swipes_path(employee_id: employee.id, month: 7, year: 2026)

    post approve_admin_correction_path(correction), headers: { "HTTP_REFERER" => referrer }

    assert_redirected_to referrer
    assert_predicate correction.reload, :approved?
  end

  test "does not review an already reviewed correction twice" do
    log_in_manager
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 4)
    )

    post reject_admin_correction_path(correction)

    assert_redirected_to admin_corrections_path
    assert_equal I18n.t("admin.flash.correction_already_reviewed"), flash[:alert]
    assert_predicate correction.reload, :approved?
  end
end
