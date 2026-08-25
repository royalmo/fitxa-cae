require "test_helper"

class Admin::CorrectionsControllerTest < ActionDispatch::IntegrationTest
  test "lists persisted corrections" do
    log_in_manager
    employee = create_employee(first_name: "Laia", last_name: "Font", national_id: valid_dni(42_200_006))
    invalidated_swipe = employee.swipes.create!(
      kind: :entry,
      swipe_at: Time.zone.local(2026, 7, 4, 8, 40),
      metadata: "employee_portal"
    )
    employee.swipes.create!(
      kind: :exit,
      swipe_at: Time.zone.local(2026, 7, 4, 13, 0),
      metadata: "employee_portal"
    )
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      requester_comments: "Oblit de fitxatge d'entrada demo 13",
      details: {
        "invalidated_swipe_ids" => [ invalidated_swipe.id ],
        "requested_swipes" => [
          { "kind" => "exit", "hour" => "17:00:00" },
          { "kind" => "entry", "hour" => "08:05:00" }
        ]
      }
    )
    validator = create_manager(
      first_name: "Montserrat",
      last_name: "Capdevila Soler",
      email: "montserrat.capdevila@example.test"
    )
    approved_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      validator: validator,
      day: Date.new(2026, 7, 5),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )

    get admin_corrections_path

    assert_response :success
    assert_match "Laia Font", response.body
    assert_no_match "Correcció de fitxatge", response.body
    assert_select "table thead tr th:first-child", text: "Estat"
    assert_select "table thead tr th", text: "Persona"
    assert_select "table thead tr th", text: "Validat per"
    assert_select "table thead tr th", text: "Antiguitat", count: 0
    assert_select ".admin-correction-person-name[title='Laia Font']", text: "Laia Font"
    assert_select ".admin-correction-person-meta[title='#{employee.national_id}']", text: employee.national_id
    assert_select ".admin-correction-validator-name[title='Montserrat Capdevila Soler']", text: "Montserrat Capdevila Soler"
    assert_select ".admin-correction-change-summary[aria-label='Entrada 08:05 · Invalidar 08:40 · Sortida existent 13:00 · Sortida 17:00']"
    assert_select ".admin-correction-change-item.is-requested.is-entry", text: "08:05"
    assert_select ".admin-correction-change-item.is-invalidate.is-entry", text: "08:40"
    assert_select ".admin-correction-change-item.is-existing.is-exit", text: "13:00"
    assert_select ".admin-correction-change-item.is-requested.is-exit", text: "17:00"
    assert_select ".admin-correction-change-item.is-existing .admin-correction-change-icon[aria-label='Sortida existent'][title='Sortida existent']"
    assert_select ".admin-correction-change-separator", 0
    assert_select ".badge.text-bg-success", text: "Aprovada"
    pending_row = Capybara.string(css_select("tr.admin-correction-row[data-correction-day='2026-07-04']").first.to_html)
    assert_equal [ "Veure", "Aprovar", "Rebutjar", "Editar" ],
      pending_row.all(".admin-row-action").map { |action| action["aria-label"] }
    approve_modal_id = "admin_correction_approve_modal_#{pending_correction.id}"
    reject_modal_id = "admin_correction_reject_modal_#{pending_correction.id}"
    assert pending_row.has_css?("button.admin-row-action.btn-outline-success[data-bs-toggle='modal'][data-bs-target='##{approve_modal_id}'][aria-label='Aprovar']")
    assert pending_row.has_css?("button.admin-row-action.btn-outline-danger[data-bs-toggle='modal'][data-bs-target='##{reject_modal_id}'][aria-label='Rebutjar']")
    assert pending_row.has_css?("a.admin-row-action[href='#{edit_admin_correction_path(pending_correction)}'][aria-label='Editar']")
    assert_not pending_row.has_css?("form[action='#{approve_admin_correction_path(pending_correction)}']")
    assert_not pending_row.has_css?("form[action='#{reject_admin_correction_path(pending_correction)}']")
    assert_not pending_row.has_css?("a.admin-row-action[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-04")}'][aria-label='Nova correcció']")
    assert_select "##{approve_modal_id}.modal.fade[aria-labelledby='#{approve_modal_id}_label']" do
      assert_select "h2##{approve_modal_id}_label", text: "Aprovar correcció"
      assert_select ".modal-body", text: /Vols aprovar la següent correcció horària/
      assert_select "dt", text: "Persona"
      assert_select ".admin-correction-review-person", text: /Laia Font/
      assert_select ".admin-correction-review-person-meta", text: employee.national_id
      assert_select "dt", text: "Dia sol·licitat"
      assert_select "dd", text: "4 Juliol 2026"
      assert_select "dt", text: "Sol·licitud"
      assert_select ".admin-correction-change-item.is-requested.is-entry", text: "08:05"
      assert_select ".admin-correction-change-item.is-invalidate.is-entry", text: "08:40"
      assert_select ".admin-correction-change-item.is-existing.is-exit", text: "13:00"
      assert_select ".admin-correction-change-item.is-requested.is-exit", text: "17:00"
      assert_select "dt", text: "Comentaris"
      assert_select "dd", text: /Oblit de fitxatge d'entrada demo 13/
      assert_select "dt", text: "Demanat"
      assert_select ".admin-correction-review-age", text: /fa menys d'1 minut/
      modal_text = css_select("##{approve_modal_id} .modal-body").first.text
      assert_operator modal_text.index("Comentaris"), :<, modal_text.index("Demanat")
      assert_select "form[action='#{approve_admin_correction_path(pending_correction)}'][method='post']" do
        assert_select "input[type='hidden'][name='server_updated_at'][value='#{correction_server_updated_at(employee, pending_correction.day)}']"
        assert_select "label[for='#{approve_modal_id}_validator_comments']", text: "Comentaris de RRHH"
        assert_select "textarea##{approve_modal_id}_validator_comments[name='validator_comments']"
        assert_select "button[type='submit'][data-submitting-label='Aprovant...']", text: "Aprovar"
      end
    end
    assert_select "##{reject_modal_id}.modal.fade[aria-labelledby='#{reject_modal_id}_label']" do
      assert_select "h2##{reject_modal_id}_label", text: "Rebutjar correcció"
      assert_select ".modal-body", text: /Vols rebutjar la següent correcció horària/
      assert_select "form[action='#{reject_admin_correction_path(pending_correction)}'][method='post']" do
        assert_select "input[type='hidden'][name='server_updated_at'][value='#{correction_server_updated_at(employee, pending_correction.day)}']"
        assert_select "label[for='#{reject_modal_id}_validator_comments']", text: "Comentaris de RRHH"
        assert_select "textarea##{reject_modal_id}_validator_comments[name='validator_comments']"
        assert_select "button[type='submit'][data-submitting-label='Rebutjant...']", text: "Rebutjar"
      end
    end
    reviewed_row = Capybara.string(css_select("tr.admin-correction-row[data-correction-day='2026-07-05']").first.to_html)
    assert_equal [ "Veure", "Nova correcció" ],
      reviewed_row.all(".admin-row-action").map { |action| action["aria-label"] }
    assert reviewed_row.has_css?("a.admin-row-action[href='#{admin_correction_path(approved_correction)}'][aria-label='Veure']")
    assert reviewed_row.has_css?("a.admin-row-action[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-05")}'][aria-label='Nova correcció']")
    assert_not reviewed_row.has_css?("a.admin-row-action[href='#{edit_admin_correction_path(approved_correction)}'][aria-label='Editar']")
    assert_not reviewed_row.has_css?("form[action='#{approve_admin_correction_path(approved_correction)}']")
    assert_not reviewed_row.has_css?("form[action='#{reject_admin_correction_path(approved_correction)}']")
    assert_select "[data-controller='list-loading']"
    assert_select "h2", text: "Filtres", count: 0
    assert_select ".admin-result-count[data-list-loading-target='results']",
      text: "Mostrant 1-#{[ SwipeCorrection.count, 20 ].min} de #{SwipeCorrection.count}"
    assert_select ".text-center .admin-result-count",
      text: "Mostrant 1-#{[ SwipeCorrection.count, 20 ].min} de #{SwipeCorrection.count}"
    assert_select "form.admin-corrections-filter-form[action='#{admin_corrections_path}'][method='get']" do
      assert_select ".admin-corrections-primary-filters" do
        assert_select ".admin-corrections-employee-filter .admin-employee-search[data-employee-search-url-value='#{admin_employee_search_path}']" do
          assert_select "input[type='hidden'][name='employee_id'][value='']"
          assert_select "input[name='employee_query'][placeholder='Cerca per nom, DNI, correu o telèfon']"
          assert_select "button[type='button'][aria-label='Totes les persones'][data-action='employee-search#clear'] svg.icon"
        end
        assert_select ".admin-corrections-tag-filter .admin-tag-search[data-tag-search-url-value='#{admin_tag_search_path}']" do
          assert_select "input[type='hidden'][name='tag_id'][value='']"
          assert_select "input[name='tag_query'][placeholder='Cerca una etiqueta']"
          assert_select "button[type='button'][aria-label='Totes les etiquetes'][data-action='tag-search#clear'] svg.icon"
        end
      end
      assert_select "select[name='employee_id']", count: 0
      assert_select "select[name='tag_id']", count: 0
      assert_select "select[name='status']", count: 0
      assert_select "input[type='radio'][name='status'][value=''][checked='checked'][autocomplete='off'] + label", text: "Totes"
      assert_select "input[type='radio'][name='status'][value='pending'][autocomplete='off'] + label svg.admin-badge-icon + span", text: "Pendents"
      assert_select "input[type='radio'][name='status'][value='approved'][autocomplete='off'] + label svg.admin-badge-icon + span", text: "Aprovades"
      assert_select "input[type='radio'][name='status'][value='rejected'][autocomplete='off'] + label svg.admin-badge-icon + span", text: "Rebutjades"
      assert_select ".admin-corrections-period-filter" do
        assert_select ".admin-corrections-period-label:not(.input-group-text)", text: /Correccions de dies en/
        assert_select ".admin-corrections-period-label span[aria-hidden='true']", 0
        assert_select "select[name='month'] option[selected][value='']", text: "Tots els mesos"
        assert_select "select[name='year'] option[selected][value='']", text: "Tots els anys"
      end
      assert_select "button[type='submit'][data-submitting-label='Filtrant...']", count: 0
    end
    assert_select "hr.admin-filters-divider"
    assert_select "button.btn.admin-row-action[aria-label='Aprovar'][data-bs-toggle='modal'] svg.icon"
    assert_select "button.btn.admin-row-action[aria-label='Rebutjar'][data-bs-toggle='modal'] svg.icon"
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

  test "filters corrections by active tag" do
    log_in_manager
    tag = Tag.create!(name: "Producció", color: "#16a34a", active: true)
    inactive_tag = Tag.create!(name: "Oficina", color: "#2563eb", active: false)
    visible_employee = create_employee(first_name: "Ada", last_name: "Soler", national_id: valid_dni(42_200_011))
    second_visible_employee = create_employee(first_name: "Jana", last_name: "Prat", national_id: valid_dni(42_200_012))
    hidden_employee = create_employee(first_name: "Ona", last_name: "Serra", national_id: valid_dni(42_200_013))
    inactive_tag_employee = create_employee(first_name: "Nil", last_name: "Font", national_id: valid_dni(42_200_014))
    visible_employee.tags << tag
    second_visible_employee.tags << tag
    inactive_tag_employee.tags << inactive_tag
    visible_employee.swipe_corrections.create!(requester: visible_employee, status: :pending, day: Date.new(2026, 7, 4))
    second_visible_employee.swipe_corrections.create!(requester: second_visible_employee, status: :approved, day: Date.new(2026, 7, 5))
    hidden_employee.swipe_corrections.create!(requester: hidden_employee, status: :pending, day: Date.new(2026, 7, 6))
    inactive_tag_employee.swipe_corrections.create!(requester: inactive_tag_employee, status: :pending, day: Date.new(2026, 7, 7))

    get admin_corrections_path, params: { tag_id: tag.id }

    assert_response :success
    row_text = css_select("tbody tr").map { |row| row.text.squish }.join(" ")
    assert_match "Ada Soler", row_text
    assert_match "Jana Prat", row_text
    assert_no_match "Ona Serra", row_text
    assert_no_match "Nil Font", row_text
    assert_select "input[name='tag_id'][value='#{tag.id}']"
    assert_select "input[name='tag_query'][value='Producció']"
    assert_select ".admin-tag-search-field.has-selected-tag" do
      assert_select ".admin-tag-search-selection.admin-tag-label[style*='#16a34a']" do
        assert_select "svg.admin-tag-label-icon + span", text: "Producció"
      end
    end
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
      assert_select "input[type='hidden'][name='swipe_correction[server_updated_at]'][value='0'][data-correction-form-target='serverUpdatedAt']"
      assert_select ".admin-employee-search[data-controller='employee-search'][data-employee-search-auto-submit-value='false']"
      assert_select "select[name='swipe_correction[employee_id]']", 0
      assert_select "input[type='hidden'][name='swipe_correction[employee_id]'][value=''][data-correction-form-target='employeeId']"
      assert_select "input[type='date'][name='swipe_correction[day]'][data-correction-form-target='date']"
      assert_select "[data-correction-form-target='emptyPrompt']", text: "Selecciona una persona i un dia per veure els fitxatges."
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
    assert_select "input[type='hidden'][name='swipe_correction[server_updated_at]'][value='0'][data-correction-form-target='serverUpdatedAt']"
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
      day: Date.new(2026, 7, 4),
      requester_comments: "Oblit de fitxatge",
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      }
    )

    get edit_admin_correction_path(correction)

    assert_response :success
    assert_select "form[data-controller='correction-form'][data-correction-form-update-url-value='false']"
    form = css_select("form[data-controller='correction-form']").first
    assert_includes form["data-action"], "submit->correction-form#confirmReviewSubmission"
    assert_equal [], JSON.parse(form["data-correction-form-initial-invalidated-swipe-ids-value"])
    assert_equal [ { "kind" => "entry", "hour" => "08:05" } ],
      JSON.parse(form["data-correction-form-initial-requested-swipes-value"])
    assert_equal "Vols aprovar aquesta correcció?", form["data-correction-form-unmodified-review-message-value"]
    assert_equal "Es rebutjarà aquesta petició i se'n crearà una altra amb els nous canvis. Procedir?",
      form["data-correction-form-modified-review-message-value"]
    modal_id = "correction_review_confirmation_modal_#{correction.id}"
    assert_select "button[type='button'][data-action='correction-form#prepareReviewConfirmation'][data-bs-toggle='modal'][data-bs-target='##{modal_id}']",
      text: "Aprovar amb modificacions"
    assert_select "button[type='submit'][data-submitting-label='Aprovant amb modificacions...']", text: "Aprovar amb modificacions", count: 0
    assert_select "##{modal_id}.modal.fade[aria-labelledby='#{modal_id}_label']" do
      assert_select "h2##{modal_id}_label", text: "Confirmar correcció"
      assert_select "p[data-correction-form-target='reviewConfirmationBody']", text: "Vols aprovar aquesta correcció?"
      assert_select "button[type='submit'][data-correction-form-confirmed='true'][data-submitting-label='Aprovant amb modificacions...']", text: "Procedir"
    end
    assert_select "input[type='hidden'][name='swipe_correction[employee_id]'][value='#{employee.id}']"
    assert_select "input[type='hidden'][name='swipe_correction[server_updated_at]'][value='#{correction_server_updated_at(employee, correction.day)}'][data-correction-form-target='serverUpdatedAt']"
    assert_select "input[name='employee_query'][value='Clara Pons'][disabled]"
    assert_select "button[data-action='employee-search#clear']", 0
    assert_select "input[type='date'][name='swipe_correction[day]'][value='2026-07-04'][disabled]"
    assert_select "input[type='hidden'][name='swipe_correction[day]'][value='2026-07-04'][data-correction-form-target='date']"
    assert_select "textarea[name='swipe_correction[requester_comments]'][disabled].admin-correction-readonly-comment", text: "Oblit de fitxatge"
    assert_select "textarea[name='swipe_correction[validator_comments]'][data-correction-form-target='comment']"
  end

  test "shows a reviewed correction with status banner details and full change summary" do
    log_in_manager
    employee = create_employee(first_name: "Aina", last_name: "Martinez Vidal", national_id: valid_dni(42_200_007))
    invalidated_swipe = employee.swipes.create!(
      kind: :entry,
      swipe_at: Time.zone.local(2026, 7, 4, 8, 40),
      metadata: "employee_portal",
      removed: true
    )
    employee.swipes.create!(
      kind: :exit,
      swipe_at: Time.zone.local(2026, 7, 4, 13, 0),
      metadata: "employee_portal"
    )
    validator = create_manager(
      first_name: "Marta",
      last_name: "Serra",
      email: "marta.serra@example.test"
    )
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      validator: validator,
      day: Date.new(2026, 7, 4),
      requester_comments: "Em vaig equivocar.",
      validator_comments: "Aprovat per RRHH.",
      details: {
        "invalidated_swipe_ids" => [ invalidated_swipe.id ],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      }
    )

    get admin_correction_path(correction)

    assert_response :success
    assert_select "a.btn.border-0[href='#{admin_corrections_path}']", text: "Tornar"
    assert_select ".admin-correction-status-banner.is-approved" do
      assert_select ".admin-correction-status-banner-copy strong", text: "Aprovada"
      assert_select ".admin-correction-status-banner-copy small", text: "Fa menys d'1 minut"
      assert_select ".admin-correction-status-banner-actions a[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-04")}']", text: "Nova correcció"
      assert_select "a[href='#{edit_admin_correction_path(correction)}']", 0
      assert_select "button[data-bs-toggle='modal']", 0
    end
    assert_no_match "Resposta:", response.body
    assert_select "dl.admin-correction-show-details", 0
    assert_select ".card .card-body dt", count: 0
    assert_select ".admin-correction-show-summary-title", text: /4 Juliol 2026/
    assert_select ".admin-correction-show-summary-title", text: /Aina Martinez Vidal/
    assert_select ".admin-correction-show-summary-separator", text: "-"
    assert_select ".admin-correction-show-summary-dni", text: /- #{employee.national_id}/
    assert_select ".admin-correction-show-summary-dni em", text: employee.national_id
    assert_select ".admin-correction-show-meta p", text: "Creada per Aina Martinez Vidal fa menys d'1 minut"
    assert_select ".admin-correction-show-meta p", text: "Aprovada per Marta Serra fa menys d'1 minut"
    assert_select ".col-xl-4", 0
    assert_select ".admin-correction-show-section h2", text: "Canvis"
    assert_select ".admin-correction-comparison[aria-label='Abans: Entrada 08:40 · Sortida 13:00. Després: Entrada 08:05 · Sortida 13:00']"
    before_row = Capybara.string(css_select(".admin-correction-comparison-row.is-before").first.to_html)
    assert before_row.has_css?(".admin-correction-comparison-label", text: "Abans:")
    assert before_row.has_css?(".admin-correction-change-item.is-existing.is-entry", text: "08:40")
    assert before_row.has_css?(".admin-correction-change-item.is-existing.is-exit", text: "13:00")
    assert before_row.has_css?(".admin-correction-change-icon[aria-label='Entrada'][title='Entrada']")
    after_row = Capybara.string(css_select(".admin-correction-comparison-row.is-after").first.to_html)
    assert after_row.has_css?(".admin-correction-comparison-label", text: "Després:")
    assert after_row.has_css?(".admin-correction-change-item.is-requested.is-entry", text: "08:05")
    assert after_row.has_css?(".admin-correction-change-item.is-existing.is-exit", text: "13:00")
    assert after_row.has_css?(".admin-correction-change-icon[aria-label='Sortida'][title='Sortida']")
    assert_select ".admin-correction-show-section .admin-correction-change-item.is-invalidate", 0
    assert_select "textarea#admin_correction_requester_comments[disabled].admin-correction-readonly-comment", text: "Em vaig equivocar."
    assert_select "textarea#admin_correction_validator_comments[disabled].admin-correction-readonly-comment", text: "Aprovat per RRHH."
    assert_select "a[href='#{edit_admin_correction_path(correction)}']", 0
  end

  test "show pending correction puts review and edit actions in the status banner" do
    log_in_manager
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      validator_comments: "Cal revisar-ho amb administració."
    )

    get admin_correction_path(correction)

    assert_response :success
    assert_select "[data-controller='correction-review-comments']"
    approve_modal_id = "admin_correction_approve_modal_#{correction.id}"
    reject_modal_id = "admin_correction_reject_modal_#{correction.id}"
    assert_select ".admin-correction-status-banner.is-pending" do
      assert_select ".admin-correction-status-banner-copy strong", text: "Pendent"
      assert_select ".admin-correction-status-banner-copy small", text: "Sol·licitada fa menys d'1 minut"
      assert_select "button[data-action='correction-review-comments#copyToModal'][data-bs-toggle='modal'][data-bs-target='##{approve_modal_id}']", text: "Aprovar"
      assert_select "button[data-action='correction-review-comments#copyToModal'][data-bs-toggle='modal'][data-bs-target='##{reject_modal_id}']", text: "Rebutjar"
      assert_select "a[href='#{edit_admin_correction_path(correction)}']", text: "Editar"
    end
    assert_no_match "Enviada:", response.body
    pending_banner = Capybara.string(css_select(".admin-correction-status-banner.is-pending").first.to_html)
    assert_not pending_banner.has_css?("a[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-04")}']")
    assert_select ".card .card-body dt", count: 0
    assert_select ".admin-correction-show-summary-title", text: /4 Juliol 2026/
    assert_select ".admin-correction-show-summary-title", text: /Clara Pons/
    assert_select ".admin-correction-show-meta p", text: "Creada per Clara Pons fa menys d'1 minut"
    assert_select ".admin-correction-show-meta p", text: /Aprovada per|Rebutjada per/, count: 0
    assert_select "textarea#admin_correction_validator_comments[data-correction-review-comments-target='source']", text: "Cal revisar-ho amb administració."
    assert_select "textarea#admin_correction_validator_comments[disabled]", 0
    assert_no_match "Sense revisar", response.body
    assert_select "##{approve_modal_id}.modal.fade textarea[name='validator_comments']", text: "Cal revisar-ho amb administració."
    assert_select "##{reject_modal_id}.modal.fade textarea[name='validator_comments']", text: "Cal revisar-ho amb administració."
    assert_select "body > .d-flex.flex-wrap.gap-2.mt-4", 0
  end

  test "show rejected correction uses feminine label and capitalized relative review age" do
    manager = create_manager(email: "rejected.validator@example.test")
    log_in_manager(manager)
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :rejected,
      validator: manager,
      day: Date.new(2026, 7, 4)
    )

    get admin_correction_path(correction)

    assert_response :success
    assert_select ".admin-correction-status-banner.is-rejected" do
      assert_select ".admin-correction-status-banner-copy strong", text: "Rebutjada"
      assert_select ".admin-correction-status-banner-copy small", text: "Fa menys d'1 minut"
    end
    assert_no_match "Resposta:", response.body
    assert_select ".admin-correction-show-meta p", text: "Creada per Ada Soler fa menys d'1 minut"
    assert_select ".admin-correction-show-meta p", text: "Rebutjada per Laia Riera fa menys d'1 minut"
  end

  test "does not edit a reviewed correction" do
    log_in_manager
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 4)
    )

    get edit_admin_correction_path(correction)

    assert_redirected_to admin_correction_path(correction)
    assert_equal I18n.t("admin.flash.correction_already_reviewed"), flash[:alert]
  end

  test "does not update a reviewed correction" do
    log_in_manager
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :rejected,
      day: Date.new(2026, 7, 4),
      requester_comments: "Original",
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )

    patch admin_correction_path(correction), params: {
      swipe_correction: {
        requester_comments: "Canviat",
        requested_swipes: [
          { kind: "entry", hour: "08:00" }
        ]
      }
    }

    assert_redirected_to admin_correction_path(correction)
    assert_equal I18n.t("admin.flash.correction_already_reviewed"), flash[:alert]
    correction.reload
    assert_equal "Original", correction.requester_comments
    assert_equal [], correction.details.fetch("requested_swipes")
  end

  test "returns day swipes for selected admin correction employee and day" do
    log_in_manager
    employee = create_employee
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 40), metadata: "employee_portal")

    get day_admin_corrections_path, params: { employee_id: employee.id, date: "2026-07-04" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["day_allowed"]
    assert_equal 0, payload["server_updated_at"]
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
    assert_select ".error-summary", text: /Ja hi ha una correcció per aquesta persona i dia/
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
            server_updated_at: correction_server_updated_at(employee, Date.new(2026, 7, 4)),
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

  test "rejects a stale manager correction create when the day changed after the form loaded" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    day = Date.new(2026, 7, 4)
    opened_server_updated_at = 0
    employee.swipe_corrections.create!(
      requester: manager,
      validator: manager,
      status: :approved,
      day: day
    )

    assert_no_difference "SwipeCorrection.count" do
      post admin_corrections_path, params: {
        swipe_correction: {
          employee_id: employee.id,
          day: day.iso8601,
          server_updated_at: opened_server_updated_at,
          requester_comments: "Alta caducada",
          requested_swipes: [
            { kind: "entry", hour: "08:00" }
          ]
        }
      }
    end

    assert_redirected_to new_admin_correction_path(employee_id: employee.id, day: day.iso8601)
    assert_equal I18n.t("admin.flash.correction_stale"), flash[:alert]
    assert_not employee.swipes.where(forged: true, kind: "entry", swipe_at: Time.zone.local(2026, 7, 4, 8, 0)).exists?
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

  test "approves a pending correction with modifications without overwriting the original request" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    other_employee = create_employee
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 45), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      requester_comments: "Original employee note",
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:10:00" } ]
      }
    )

    assert_difference "SwipeCorrection.count", 1 do
      assert_difference -> { employee.swipes.count }, 1 do
        patch admin_correction_path(correction), params: {
          swipe_correction: {
            employee_id: other_employee.id,
            day: "2026-07-05",
            server_updated_at: correction_server_updated_at(employee, correction.day),
            validator_comments: "Hora ajustada per RRHH",
            invalidated_swipe_ids: [ swipe.id ],
            requested_swipes: {
              "0" => { kind: "entry", hour: "08:00" }
            }
          }
        }
      end
    end

    correction.reload
    replacement = SwipeCorrection.find_by!(requester: manager, requester_comments: "Hora ajustada per RRHH")
    assert_redirected_to admin_correction_path(replacement)
    assert_predicate correction, :rejected?
    assert_equal manager, correction.validator
    assert_equal I18n.t("admin.corrections.review.approved_with_modifications"), correction.validator_comments
    assert_equal "Original employee note", correction.requester_comments
    assert_equal [ { "kind" => "entry", "hour" => "08:10:00" } ], correction.details.fetch("requested_swipes")
    assert_predicate replacement, :approved?
    assert_equal manager, replacement.validator
    assert_equal employee, replacement.employee
    assert_equal Date.new(2026, 7, 4), replacement.day
    assert_equal [ swipe.id.to_s ], replacement.details.fetch("invalidated_swipe_ids")
    assert_equal [ { "kind" => "entry", "hour" => "08:00:00" } ], replacement.details.fetch("requested_swipes")
    assert_predicate swipe.reload, :removed?
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{replacement.id}", kind: "entry", swipe_at: Time.zone.local(2026, 7, 4, 8, 0)).exists?
  end

  test "approves the original pending correction from edit when hours are unchanged" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:10:00" } ]
      }
    )

    assert_no_difference "SwipeCorrection.count" do
      assert_difference -> { employee.swipes.count }, 1 do
        patch admin_correction_path(correction), params: {
          swipe_correction: {
            server_updated_at: correction_server_updated_at(employee, correction.day),
            validator_comments: "Només comentari",
            requested_swipes: {
              "0" => { kind: "entry", hour: "08:10" }
            }
          }
        }
      end
    end

    assert_redirected_to admin_correction_path(correction)
    assert_equal I18n.t("admin.flash.correction_approved"), flash[:notice]
    correction.reload
    assert_predicate correction, :approved?
    assert_equal manager, correction.validator
    assert_equal "Només comentari", correction.validator_comments
    assert_equal [ { "kind" => "entry", "hour" => "08:10:00" } ], correction.details.fetch("requested_swipes")
    assert_not SwipeCorrection.where(requester: manager, requester_comments: "Només comentari").exists?
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{correction.id}", kind: "entry", swipe_at: Time.zone.local(2026, 7, 4, 8, 10)).exists?
  end

  test "rejects a stale pending correction edit" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      requester_comments: "Original employee note",
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:10:00" } ]
      }
    )
    opened_server_updated_at = correction_server_updated_at(employee, correction.day)
    correction.update!(requester_comments: "Employee edited note")

    assert_no_difference "SwipeCorrection.count" do
      patch admin_correction_path(correction), params: {
        swipe_correction: {
          server_updated_at: opened_server_updated_at,
          validator_comments: "Hora caducada",
          requested_swipes: {
            "0" => { kind: "entry", hour: "08:00" }
          }
        }
      }
    end

    assert_redirected_to edit_admin_correction_path(correction)
    assert_equal I18n.t("admin.flash.correction_stale"), flash[:alert]
    correction.reload
    assert_predicate correction, :pending?
    assert_nil correction.validator
    assert_equal "Employee edited note", correction.requester_comments
    assert_equal [ { "kind" => "entry", "hour" => "08:10:00" } ], correction.details.fetch("requested_swipes")
    assert_not SwipeCorrection.where(requester: manager, requester_comments: "Hora caducada").exists?
  end

  test "update keeps employee and day from the original pending correction" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    other_employee = create_employee
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 45), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )

    patch admin_correction_path(correction), params: {
      swipe_correction: {
        employee_id: other_employee.id,
        day: "2026-07-05",
        server_updated_at: correction_server_updated_at(employee, correction.day),
        validator_comments: "Manté identitat",
        invalidated_swipe_ids: [ swipe.id ]
      }
    }

    replacement = SwipeCorrection.find_by!(requester: manager, requester_comments: "Manté identitat")
    assert_redirected_to admin_correction_path(replacement)
    assert_equal employee, correction.employee
    assert_equal Date.new(2026, 7, 4), correction.day
    assert_equal employee, replacement.employee
    assert_equal Date.new(2026, 7, 4), replacement.day
    assert_equal [ swipe.id.to_s ], replacement.details.fetch("invalidated_swipe_ids")
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
      post approve_admin_correction_path(correction), params: {
        server_updated_at: correction_server_updated_at(employee, correction.day),
        validator_comments: "Revisat i correcte."
      }
    end

    assert_redirected_to admin_corrections_path
    correction.reload
    assert_predicate correction, :approved?
    assert_equal manager, correction.validator
    assert_equal "Revisat i correcte.", correction.validator_comments
    assert_predicate old_swipe.reload, :removed?
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{correction.id}").exists?(kind: "exit")
    assert employee.swipes.where(swipe_at: Time.zone.local(2026, 7, 4, 17, 0)).exists?
  end

  test "rejects a stale pending correction approval" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      }
    )
    opened_server_updated_at = correction_server_updated_at(employee, correction.day)
    correction.update!(
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:15:00" } ]
      }
    )

    assert_no_difference "employee.swipes.count" do
      post approve_admin_correction_path(correction), params: {
        server_updated_at: opened_server_updated_at,
        validator_comments: "Aprovar versió caducada"
      }
    end

    assert_redirected_to admin_corrections_path
    assert_equal I18n.t("admin.flash.correction_stale"), flash[:alert]
    correction.reload
    assert_predicate correction, :pending?
    assert_nil correction.validator
    assert_equal [ { "kind" => "entry", "hour" => "08:15:00" } ], correction.details.fetch("requested_swipes")
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
      post reject_admin_correction_path(correction), params: {
        server_updated_at: correction_server_updated_at(employee, correction.day),
        validator_comments: "No s'accepta el canvi."
      }
    end

    assert_redirected_to admin_corrections_path
    correction.reload
    assert_predicate correction, :rejected?
    assert_equal manager, correction.validator
    assert_equal "No s'accepta el canvi.", correction.validator_comments
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

    post approve_admin_correction_path(correction),
      params: { server_updated_at: correction_server_updated_at(employee, correction.day) },
      headers: { "HTTP_REFERER" => referrer }

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
