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
    assert_equal "Vaig entrar abans.", correction.requester_comments
  end

  test "new correction form starts empty without a day param" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get new_correction_path
    end

    assert_response :success
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
    assert_select ".correction-existing-swipe", text: /08:40/
    assert_select ".correction-select-day-state[hidden]"
    assert_select ".correction-loading-state[hidden]"
    assert_select ".correction-form-details[hidden]", 0
    assert_select "select[name='kind']", 0
    assert_select "input[name='time']", 0
  end

  test "loads correction day swipes and pending correction as json" do
    employee = create_employee(password: "1234")
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 40), metadata: "employee_portal")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [ swipe.id ],
        "requested_swipes" => [ { "kind" => "entry", "hour" => "08:05:00" } ]
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
    assert_equal [ swipe.id.to_s ], payload["pending_correction"]["invalidated_swipe_ids"]
    assert_equal [ { "kind" => "entry", "time" => "08:05:00" } ], payload["pending_correction"]["requested_swipes"]
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
    assert_select ".error-summary", text: I18n.t("employee.corrections.create.date_out_of_range")
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
  end

  test "lists corrections from the signed in employee" do
    employee = create_employee(password: "1234")
    other_employee = create_employee(national_id: valid_dni(12_345_679), password: "1234")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ]
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
    assert_match "Sortida oblidada", response.body
    assert_no_match "No visible", response.body
    assert_select ".correction-status-icon[aria-label='Pendent'][title='Pendent']"
    assert_select ".correction-row .badge-pending", 0
  end

  test "filters corrections by status and month" do
    employee = create_employee(password: "1234")
    employee.swipe_corrections.create!(
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
    get corrections_path, params: { status: "approved", month: "2026-07" }

    assert_response :success
    assert_select "form.corrections-filter-form"
    assert_select "select[name='status'] option[selected][value='approved']"
    assert_select "select[name='status'] option[value='approved']", text: "👍 Aprovat"
    assert_select "select[name='status'] option[value='rejected']", text: "👎 Rebutjat"
    assert_select "select[name='status'] option[value='pending']", text: "⌛ Pendent"
    assert_select "select[name='month'] option[selected][value='2026-07']"
    assert_select ".correction-row", 1
    assert_match "Visible aprovada", response.body
    assert_no_match "Pendent juliol", response.body
    assert_no_match "Aprovada juny", response.body
  end

  test "paginates corrections twenty per page" do
    employee = create_employee(password: "1234")

    25.times do |index|
      employee.swipe_corrections.create!(
        requester: employee,
        status: :pending,
        day: Date.new(2026, 7, 1) + index.days,
        details: { "invalidated_swipe_ids" => [], "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ] },
        requester_comments: "Correccio #{index}"
      )
    end

    log_in_employee(employee)
    get corrections_path

    assert_response :success
    assert_select ".correction-row", 20
    assert_select ".corrections-page-status", text: "Pàgina 1 de 2"
    assert_select "a.corrections-page-link[href='#{corrections_path(page: 2)}']", text: "Següent"
    assert_match "Correccio 24", response.body
    assert_no_match "Correccio 0", response.body

    get corrections_path, params: { page: 2 }

    assert_response :success
    assert_select ".correction-row", 5
    assert_select ".corrections-page-status", text: "Pàgina 2 de 2"
    assert_match "Correccio 0", response.body
  end
end
