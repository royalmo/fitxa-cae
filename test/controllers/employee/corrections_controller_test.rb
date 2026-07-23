require "test_helper"

class Employee::CorrectionsControllerTest < ActionDispatch::IntegrationTest
  test "creates a pending swipe correction for the signed in employee" do
    employee = create_employee(password: "1234")
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 40), metadata: "employee_portal")
    log_in_employee(employee)

    assert_difference "SwipeCorrection.count", 1 do
      post corrections_path, params: {
        date: "2026-07-02",
        note: "Vaig entrar abans.",
        invalidated_swipe_ids: [ swipe.id ],
        requested_swipes: [
          { kind: "entry", time: "08:05" },
          { kind: "entry", time: "13:00" },
          { kind: "exit", time: "17:00" }
        ]
      }
    end

    assert_redirected_to corrections_path
    correction = employee.swipe_corrections.last
    assert_equal "pending", correction.status
    assert_equal employee, correction.requester
    assert_equal Date.new(2026, 7, 2), correction.day
    assert_equal [ swipe.id ], correction.details["invalidated_swipe_ids"]
    assert_equal "entry", correction.details["requested_swipes"].first["kind"]
    assert_equal "08:05:00", correction.details["requested_swipes"].first["hour"]
    assert_equal [ "entry", "entry", "exit" ], correction.details["requested_swipes"].map { |requested_swipe| requested_swipe["kind"] }
    assert_equal "Vaig entrar abans.", correction.requester_comments
  end

  test "new correction form starts empty without a day param" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get new_correction_path
    end

    assert_response :success
    assert_select "a.page-title-close[href='#{corrections_path}'][title='#{I18n.t("employee.corrections.new.back_to_list")}'][aria-label='#{I18n.t("employee.corrections.new.back_to_list")}']"
    assert_select "input[type='date'][name='date'][value]", 0
    assert_select ".correction-select-day-state", text: "Selecciona un dia per sol·licitar una correcció."
    assert_select ".correction-select-day-state .empty-state-icon"
    assert_select ".correction-loading-state[hidden]", text: "Carregant..."
    assert_select ".correction-form-details[hidden]"
  end

  test "new correction form accepts a day param within the correction window" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 6, 3, 8, 40), metadata: "employee_portal")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get new_correction_path, params: { day: "2026-06-03" }
    end

    assert_response :success
    assert_select "input[type='date'][name='date'][value='2026-06-03'][min='2026-06-01'][max='2026-07-19']"
    assert_select ".correction-swipe-column", 2
    assert_select ".correction-swipe-column[data-kind='entry'] .correction-swipe-column-header", text: "Entrades"
    assert_select ".correction-swipe-column[data-kind='exit'] .correction-swipe-column-header", text: "Sortides"
    assert_select ".correction-swipe-column[data-kind='entry'] .correction-existing-swipe", text: /08:40/
    assert_select ".correction-swipe-request-cell", 0
    assert_select ".correction-swipe-request-cell select", 0
    assert_select ".correction-swipe-empty-slot", 0
    assert_select ".correction-swipe-column[data-kind='entry'] button.correction-requested-swipe-add[data-action='correction-form#addRequestedSwipe'][data-kind='entry']", text: /Afegir entrada/
    assert_select ".correction-swipe-column[data-kind='exit'] button.correction-requested-swipe-add[data-action='correction-form#addRequestedSwipe'][data-kind='exit']", text: /Afegir sortida/
    assert_select ".correction-swipe-table-row", 0
    assert_select ".correction-select-day-state[hidden]"
    assert_select ".correction-loading-state[hidden]"
    assert_select ".correction-form-details[hidden]", 0
    assert_select "select[name='kind']", 0
    assert_select "input[name='time']", 0
  end

  test "new correction form shows delete button for a pending correction" do
    employee = create_employee(password: "1234")
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [
          { "kind" => "entry", "hour" => "13:10:00" },
          { "kind" => "entry", "hour" => "08:05:00" },
          { "kind" => "exit", "hour" => "17:30:00" }
        ]
      },
      requester_comments: "Correcció pendent"
    )
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get new_correction_path, params: { day: "2026-07-02" }
    end

    assert_response :success
    assert_select ".correction-pending-note", text: I18n.t("employee.corrections.new.pending_loaded")
    assert_select ".correction-delete-action[hidden]", 0
    assert_select "a.correction-delete-button[href='#{correction_path(pending_correction)}'][data-turbo-method='delete']", text: /Eliminar sol·licitud/
    assert_select "a.correction-delete-button[data-turbo-confirm]", 0
    assert_select ".correction-swipe-column[data-kind='entry'] .correction-swipe-request-cell", 2
    assert_select ".correction-swipe-column[data-kind='exit'] .correction-swipe-request-cell", 1
    assert_select ".correction-swipe-request-cell .correction-existing-swipe.correction-requested-swipe", 3
    assert_select ".correction-swipe-request-cell .correction-existing-swipe-main", 3
    assert_select ".correction-swipe-request-cell .correction-existing-swipe-copy", 3
    assert_select ".correction-swipe-request-cell .correction-existing-swipe-kind-icon", 3
    assert_select ".correction-swipe-request-cell .correction-existing-swipe-state.correction-requested-swipe-remove", 3
    assert_select ".correction-swipe-request-cell input[type='time'][name='requested_swipes[][time]'][value='08:05']"
    assert_select ".correction-swipe-request-cell input[type='time'][name='requested_swipes[][time]'][value='13:10']"
    assert_select ".correction-swipe-request-cell input[type='time'][name='requested_swipes[][time]'][value='17:30']"
    assert_select ".correction-swipe-column[data-kind='entry'] .correction-swipe-request-cell input[type='time']" do |inputs|
      assert_equal %w[08:05 13:10], inputs.map { |input| input["value"] }
    end
    assert_select "button.correction-requested-swipe-remove[aria-label='#{I18n.t("employee.corrections.new.remove_requested_swipe")}']", 3
  end

  test "blank requested swipe inputs are ignored when another correction change exists" do
    employee = create_employee(password: "1234")
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 40), metadata: "employee_portal")
    log_in_employee(employee)

    assert_difference "SwipeCorrection.count", 1 do
      post corrections_path, params: {
        date: "2026-07-02",
        invalidated_swipe_ids: [ swipe.id ],
        requested_swipes: [
          { kind: "entry", time: "" },
          { kind: "exit", time: "" }
        ]
      }
    end

    assert_redirected_to corrections_path
    correction = employee.swipe_corrections.last
    assert_equal [ swipe.id ], correction.details["invalidated_swipe_ids"]
    assert_equal [], correction.details["requested_swipes"]
  end

  test "loads correction day swipes and pending correction as json" do
    employee = create_employee(password: "1234")
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 40), metadata: "employee_portal")
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [ swipe.id ],
        "requested_swipes" => [
          { "kind" => "entry", "hour" => "13:10:00" },
          { "kind" => "entry", "hour" => "08:05:00" }
        ]
      },
      requester_comments: "Correcció pendent"
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get day_corrections_path, params: { date: "2026-07-02" }, as: :json
    end

    assert_response :success
    payload = response.parsed_body
    assert_equal true, payload["day_allowed"]
    assert_equal pending_correction.id.to_s, payload["pending_correction"]["id"]
    assert_equal correction_path(pending_correction), payload["pending_correction"]["delete_url"]
    assert_equal [ swipe.id.to_s ], payload["pending_correction"]["invalidated_swipe_ids"]
    assert_equal [
      { "kind" => "entry", "time" => "08:05:00" },
      { "kind" => "entry", "time" => "13:10:00" }
    ], payload["pending_correction"]["requested_swipes"]
    assert_equal "Correcció pendent", payload["pending_correction"]["comment"]
    assert_equal "08:40", payload["swipes"].first["time"]
  end

  test "updates an existing pending correction for the same employee and day" do
    employee = create_employee(password: "1234")
    old_swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 40), metadata: "employee_portal")
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:10:00" } ]
      },
      requester_comments: "Primera versió"
    )

    log_in_employee(employee)

    assert_no_difference "SwipeCorrection.count" do
      post corrections_path, params: {
        date: "2026-07-02",
        note: "Versió editada",
        invalidated_swipe_ids: [ old_swipe.id ],
        requested_swipes: [ { kind: "exit", time: "17:30" } ]
      }
    end

    assert_redirected_to corrections_path
    pending_correction.reload
    assert_equal "Versió editada", pending_correction.requester_comments
    assert_equal [ old_swipe.id ], pending_correction.details["invalidated_swipe_ids"]
    assert_equal [ { "kind" => "exit", "hour" => "17:30:00" } ], pending_correction.details["requested_swipes"]
  end

  test "deletes a pending correction for the signed in employee" do
    employee = create_employee(password: "1234")
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      },
      requester_comments: "Correcció pendent"
    )
    log_in_employee(employee)

    assert_no_difference -> { SwipeCorrection.with_deleted.count } do
      assert_difference -> { SwipeCorrection.count }, -1 do
        delete correction_path(pending_correction)
      end
    end

    assert_redirected_to corrections_path
    assert_not_nil SwipeCorrection.deleted.find(pending_correction.id).deleted_at
    assert_equal I18n.t("employee.flash.correction_deleted"), flash[:notice][:message]
    assert_equal I18n.t("employee.flash.undo"), flash[:notice][:action][:label]
    assert_equal restore_correction_path(pending_correction), flash[:notice][:action][:path]
    assert_equal :post, flash[:notice][:action][:method]

    follow_redirect!

    assert_select ".flash-message", text: I18n.t("employee.flash.correction_deleted")
    assert_select "form.flash-action-form[action='#{restore_correction_path(pending_correction)}'][method='post']"
    assert_select ".flash-action", text: I18n.t("employee.flash.undo")
  end

  test "restores a soft deleted pending correction and returns to the correction form" do
    employee = create_employee(password: "1234")
    pending_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      },
      requester_comments: "Correcció pendent"
    )
    pending_correction.soft_delete!
    log_in_employee(employee)

    post restore_correction_path(pending_correction)

    assert_redirected_to new_correction_path(day: "2026-07-02")
    assert_nil pending_correction.reload.deleted_at
    assert_equal I18n.t("employee.flash.correction_restored"), flash[:notice]
  end

  test "rejects correction requests outside current and previous month" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      assert_no_difference "SwipeCorrection.count" do
        post corrections_path, params: {
          date: "2026-05-31",
          requested_swipes: [ { kind: "entry", time: "08:05" } ],
          note: "Massa antic"
        }
      end
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary .error-summary-content", text: I18n.t("employee.corrections.create.date_out_of_range")
    assert_select ".error-summary[data-controller='dismissible'][role='alert']"
    assert_select ".error-summary .error-summary-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
  end

  test "rejects incomplete correction requests" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    assert_no_difference "SwipeCorrection.count" do
      post corrections_path, params: {
        date: "",
        requested_swipes: [ { kind: "not-supported", time: "" } ],
        note: "Sense dades"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary"
    assert_select ".error-summary .error-summary-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
    assert_select "form.correction-form[data-action='input->correction-form#dismissErrors change->correction-form#dismissErrors focusout->correction-form#sortRequestedSwipeColumn']"
  end

  test "rejects correction requests without any changes" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      assert_no_difference "SwipeCorrection.count" do
        post corrections_path, params: {
          date: "2026-07-02",
          requested_swipes: [],
          note: "Sense canvis"
        }
      end
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary .error-summary-content", text: I18n.t("employee.corrections.create.missing_changes")
    assert_select ".error-summary .error-summary-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
    assert_select "form.correction-form[data-action='input->correction-form#dismissErrors change->correction-form#dismissErrors focusout->correction-form#sortRequestedSwipeColumn']"
  end

  test "lists corrections from the signed in employee" do
    employee = create_employee(password: "1234")
    other_employee = create_employee(national_id: valid_dni(12_345_679), password: "1234")
    invalidated_swipe = employee.swipes.create!(
      kind: :entry,
      swipe_at: Time.zone.local(2026, 7, 2, 8, 40),
      metadata: "employee_portal"
    )
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [ invalidated_swipe.id ],
        "requested_swipes" => [
          { "kind" => "exit", "hour" => "17:00:00" },
          { "kind" => "entry", "hour" => "08:05:00" }
        ]
      },
      requester_comments: "Sortida oblidada"
    )
    other_employee.swipe_corrections.create!(
      requester: other_employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] },
      requester_comments: "No visible"
    )

    log_in_employee(employee)
    get corrections_path

    assert_response :success
    assert_select "a.correction-row" do |links|
      assert_includes links.map { |link| link["href"] }, new_correction_path(day: "2026-07-02")
    end
    assert_select ".correction-day-title time[datetime='2026-07-02']", text: I18n.l(correction.day, format: :weekday_day_month)
    assert_no_match "Correcció de fitxatge", response.body
    assert_no_match "Hora sol·licitada", response.body
    assert_no_match "Sortida oblidada", response.body
    assert_no_match "No visible", response.body
    assert_select ".correction-change-summary[aria-label='Entrada 08:05 · Invalidar 08:40 · Sortida 17:00']"
    assert_select ".correction-change-item > span" do |times|
      assert_equal %w[08:05 08:40 17:00], times.map { |time| time.text.squish }
    end
    assert_select ".correction-change-item.is-entry .correction-change-icon[aria-label='Entrada'][title='Entrada']"
    assert_select ".correction-change-item.is-invalidate .correction-change-icon[aria-label='Invalidar'][title='Invalidar']"
    assert_select ".correction-change-item.is-exit .correction-change-icon[aria-label='Sortida'][title='Sortida']"
    assert_select ".correction-change-separator", 2
    assert_select ".correction-status-icon[aria-label='Pendent'][title='Pendent']"
    assert_select ".correction-row-action-icon[aria-label='Editar'][title='Editar']"
    assert_select ".correction-human-resources-icon", 0
    assert_select ".correction-human-resources-marker", 0
    assert_select ".correction-answer", 0
    assert_no_match "Pendent de revisió", response.body
    assert_select ".correction-row .badge-pending", 0
  end

  test "marks corrections created by human resources in the list" do
    manager = create_manager
    employee = create_employee(password: "1234")
    correction = employee.swipe_corrections.create!(
      requester: manager,
      status: :approved,
      validator: manager,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      }
    )

    log_in_employee(employee)
    get corrections_path, params: { month: 7, year: 2026 }

    assert_response :success
    assert_select "a.correction-row[href='#{correction_path(correction)}'] .correction-day-title" do
      assert_select "time[datetime='2026-07-02']", text: I18n.l(correction.day, format: :weekday_day_month)
      assert_select(
        ".correction-human-resources-marker" \
          "[aria-label='Correcció realitzada per RRHH']" \
          "[data-tooltip='Correcció realitzada per RRHH']"
      )
      assert_select ".correction-human-resources-marker[title]", 0
      assert_select ".correction-human-resources-marker .correction-human-resources-icon[aria-hidden='true']"
    end
  end

  test "does not show result count when corrections list is empty" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get corrections_path
    end

    assert_response :success
    assert_select ".corrections-empty-state", text: I18n.t("employee.corrections.index.empty")
    assert_select ".corrections-result-count", 0
    assert_select "#corrections_month[disabled]", 0
    assert_select "#corrections_year[disabled]", 0
  end

  test "shows month-specific empty message for older correction months" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get corrections_path, params: { month: 6, year: 2026 }
    end

    assert_response :success
    assert_select ".corrections-empty-state", text: "No hi ha correccions en aquest mes."

    {
      pending: "No hi ha correccions pendents en aquest mes.",
      approved: "No hi ha correccions aprovades en aquest mes.",
      rejected: "No hi ha correccions rebutjades en aquest mes."
    }.each do |status, message|
      travel_to Time.zone.local(2026, 7, 19, 12, 0) do
        get corrections_path, params: { month: 6, year: 2026, status: status }
      end

      assert_response :success
      assert_select ".corrections-empty-state", text: message
    end
  end

  test "keeps unreachable correction month params in filter form" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get corrections_path, params: { month: 5, year: 2013 }
    end

    assert_response :success
    assert_select "#corrections_month option[selected][disabled][value='5']"
    assert_select "#corrections_year option[selected][disabled][value='2013']"
    assert_select "input[type='hidden'][name='month'][value='5']"
    assert_select "input[type='hidden'][name='year'][value='2013']"

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get corrections_path, params: { month: 5, year: 2013, status: "approved" }
    end

    assert_response :success
    assert_select "input[type='radio'][name='status'][value='approved'][checked]"
    assert_select "#corrections_month option[selected][disabled][value='5']"
    assert_select "#corrections_year option[selected][disabled][value='2013']"
    assert_select "input[type='hidden'][name='month'][value='5']"
    assert_select "input[type='hidden'][name='year'][value='2013']"
  end

  test "keeps requested unreachable year when month param is missing" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get corrections_path, params: { year: 2013 }
    end

    assert_response :success
    assert_select "#corrections_month option[selected][disabled][value='7']"
    assert_select "#corrections_year option[selected][disabled][value='2013']"
    assert_select "input[type='hidden'][name='month'][value='7']"
    assert_select "input[type='hidden'][name='year'][value='2013']"
  end

  test "defaults correction month filter to the latest month with corrections" do
    employee = create_employee(password: "1234")
    older_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 5, 30),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )
    latest_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 6, 30),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get corrections_path
    end

    assert_response :success
    assert_select "#corrections_month option[selected][value='6']"
    assert_select "#corrections_year option[selected][value='2026']"
    assert_select ".correction-row", 1
    assert_select "a.correction-row" do |links|
      hrefs = links.map { |link| link["href"] }

      assert_includes hrefs, new_correction_path(day: latest_correction.day.iso8601)
      assert_not_includes hrefs, correction_path(older_correction)
    end
  end

  test "filters corrections by status and month" do
    employee = create_employee(password: "1234")
    approved_correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 2),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ] },
      requester_comments: "Visible aprovada"
    )
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 3),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [ { "kind" => "entry", "hour" => "08:00:00" } ] },
      requester_comments: "Pendent juliol"
    )
    employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 6, 30),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [ { "kind" => "entry", "hour" => "08:30:00" } ] },
      requester_comments: "Aprovada juny"
    )

    log_in_employee(employee)
    get corrections_path, params: { status: "approved", month: 7, year: 2026 }

    assert_response :success
    assert_select "[data-controller='list-loading']"
    assert_select "form.corrections-filter-form"
    assert_select "fieldset.corrections-filter-panel > legend.sr-only", text: "Filtrar per"
    assert_select "fieldset.corrections-filter-panel > .corrections-filter-header > .corrections-filter-heading", text: "Filtrar per:"
    assert_select "fieldset.corrections-filter-panel > .corrections-filter-header > .corrections-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select "fieldset.corrections-filter-panel > hr.corrections-filter-divider"
    assert_select "[data-list-loading-target='results']"
    assert_select ".list-loading-state[data-list-loading-target='loading'][hidden]", text: "Carregant..."
    assert_select ".corrections-status-filter legend.sr-only", text: "Estat"
    assert_select ".corrections-status-filter > .corrections-filter-label", text: "Estat:"
    assert_select "input[type='radio'][name='status'][value='']", 1
    assert_select "input[type='radio'][name='status'][value=''][checked]", 0
    assert_select "input[type='radio'][name='status'][value=''][autocomplete='off'] + span", text: "Totes"
    assert_select "input[type='radio'][name='status'][value='pending'][autocomplete='off'] + svg.corrections-status-option-icon + span", text: "Pendents"
    assert_select "input[type='radio'][name='status'][value='approved'][checked][autocomplete='off'] + svg.corrections-status-option-icon + span", text: "Aprovades"
    assert_select "input[type='radio'][name='status'][value='approved'][data-action='change->list-loading#filter']"
    assert_select "input[type='radio'][name='status'][value='rejected'][autocomplete='off'] + svg.corrections-status-option-icon + span", text: "Rebutjades"
    assert_select ".corrections-month-filter", text: /Mes:/
    assert_select "#corrections_month[data-action='change->list-loading#filter'] option[selected][value='7']"
    assert_select "#corrections_year[data-action='change->list-loading#filter'] option[selected][value='2026']"
    assert_select ".corrections-result-count", text: "Mostrant 1-1 de 1"
    assert_select ".correction-row", 1
    assert_select "a.correction-row[href='#{correction_path(approved_correction)}']", 1
    assert_select ".correction-day-title time[datetime='2026-07-02']", text: I18n.l(approved_correction.day, format: :weekday_day_month)
    assert_select ".correction-row-action-icon[aria-label='Veure'][title='Veure']"
    assert_select ".correction-answer", 0
    assert_no_match "Visible aprovada", response.body
    assert_no_match "Pendent juliol", response.body
    assert_no_match "Aprovada juny", response.body
  end

  test "shows a reviewed correction as read only" do
    manager = create_manager
    employee = create_employee(password: "1234")
    invalidated_swipe = employee.swipes.create!(
      kind: :entry,
      swipe_at: Time.zone.local(2026, 7, 2, 8, 40),
      metadata: "employee_portal",
      removed: true
    )
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      validator: manager,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [ invalidated_swipe.id ],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
      },
      requester_comments: "Em vaig equivocar.",
      validator_comments: "Aprovat per RRHH."
    )
    log_in_employee(employee)

    get correction_path(correction)

    assert_response :success
    assert_select "h1.page-title", text: I18n.l(correction.day, format: :weekday_day_month)
    assert_select "a.page-title-close[href='#{corrections_path}']"
    assert_select ".correction-show-status.is-approved"
    assert_select ".correction-show-status span", text: "Aprovada"
    assert_select ".correction-show-status .correction-status-icon[aria-label='Aprovada'][title='Aprovada']"
    assert_select ".correction-show-block h2" do |headings|
      heading_texts = headings.map { |heading| heading.text.squish }

      assert_includes heading_texts, "Comentari"
    end
    assert_select ".correction-readonly-swipe[data-kind='entry']", text: "08:40"
    assert_select ".correction-readonly-swipe[data-kind='entry']", text: "08:05"
    assert_match "Em vaig equivocar.", response.body
    assert_match "Aprovat per RRHH.", response.body
    assert_select "form.correction-form", 0
    assert_select ".correction-swipe-request-cell input[type='time']", 0
  end

  test "shows human resources comment title when a reviewed correction was requested by a manager" do
    manager = create_manager
    employee = create_employee(password: "1234")
    correction = employee.swipe_corrections.create!(
      requester: manager,
      status: :approved,
      validator: manager,
      day: Date.new(2026, 7, 2),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] },
      requester_comments: "Comentari intern de RRHH."
    )
    log_in_employee(employee)

    get correction_path(correction)

    assert_response :success
    assert_select ".correction-show-status.is-approved"
    assert_select ".correction-show-status span", text: "Creada per RRHH"
    assert_select ".correction-show-status .correction-status-icon[aria-label='Creada per RRHH']" \
      "[title='Creada per RRHH']"
    assert_select ".correction-show-block h2", text: "Comentari de Recursos Humans"
    assert_match "Comentari intern de RRHH.", response.body
  end

  test "shows rejected human resources correction status if one exists" do
    manager = create_manager
    employee = create_employee(password: "1234")
    correction = employee.swipe_corrections.create!(
      requester: manager,
      status: :rejected,
      validator: manager,
      day: Date.new(2026, 7, 2),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )
    log_in_employee(employee)

    get correction_path(correction)

    assert_response :success
    assert_select ".correction-show-status.is-rejected"
    assert_select ".correction-show-status span", text: "Creada i rebutjada per RRHH"
    assert_select ".correction-show-status .correction-status-icon[aria-label='Creada i rebutjada per RRHH']" \
      "[title='Creada i rebutjada per RRHH']"
  end

  test "redirects pending correction detail to the editable correction form" do
    employee = create_employee(password: "1234")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )
    log_in_employee(employee)

    get correction_path(correction)

    assert_redirected_to new_correction_path(day: "2026-07-02")
  end

  test "paginates corrections ten per page" do
    employee = create_employee(password: "1234")

    25.times do |index|
      employee.swipe_corrections.create!(
        requester: employee,
        status: :pending,
        day: Date.new(2026, 7, 1) + (index % 28).days,
        details: { "invalidated_swipe_ids" => [], "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ] },
        requester_comments: "Correccio #{index}"
      )
    end

    log_in_employee(employee)
    get corrections_path

    assert_response :success
    assert_select ".correction-row", 10
    assert_select ".corrections-result-count", text: "Mostrant 1-10 de 25"
    assert_select ".corrections-page-status", text: "Pàgina 1 de 3"
    assert_select "a.corrections-page-link[href='#{corrections_path(month: 7, year: 2026, page: 2)}'][data-action='click->list-loading#navigate']", text: "Següent"
    assert_select "a.correction-row" do |links|
      hrefs = links.map { |link| link["href"] }

      assert_includes hrefs, new_correction_path(day: "2026-07-25")
      assert_includes hrefs, new_correction_path(day: "2026-07-16")
      assert_not_includes hrefs, new_correction_path(day: "2026-07-15")
    end

    get corrections_path, params: { month: 7, year: 2026, page: 2 }

    assert_response :success
    assert_select ".correction-row", 10
    assert_select ".corrections-result-count", text: "Mostrant 11-20 de 25"
    assert_select ".corrections-page-status", text: "Pàgina 2 de 3"
    assert_select "a.correction-row" do |links|
      hrefs = links.map { |link| link["href"] }

      assert_includes hrefs, new_correction_path(day: "2026-07-15")
      assert_not_includes hrefs, new_correction_path(day: "2026-07-01")
    end

    get corrections_path, params: { month: 7, year: 2026, page: 3 }

    assert_response :success
    assert_select ".correction-row", 5
    assert_select ".corrections-result-count", text: "Mostrant 21-25 de 25"
    assert_select ".corrections-page-status", text: "Pàgina 3 de 3"
    assert_select "a.correction-row" do |links|
      assert_includes links.map { |link| link["href"] }, new_correction_path(day: "2026-07-01")
    end
  end
end
