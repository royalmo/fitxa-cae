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

  test "creates a manager correction with requested swipes" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee

    assert_difference "SwipeCorrection.count", 1 do
      post admin_corrections_path, params: {
        swipe_correction: {
          employee_id: employee.id,
          day: "2026-07-04",
          requester_comments: "Alta manual",
          requested_swipes: {
            "0" => { kind: "entry", hour: "08:00" },
            "1" => { kind: "exit", hour: "16:30" }
          }
        }
      }
    end

    correction = SwipeCorrection.order(:created_at).last
    assert_redirected_to admin_correction_path(correction)
    assert_equal manager, correction.requester
    assert_equal "Alta manual", correction.requester_comments
    assert_equal [
      { "kind" => "entry", "hour" => "08:00:00" },
      { "kind" => "exit", "hour" => "16:30:00" }
    ], correction.details.fetch("requested_swipes")
  end

  test "updates a correction and selected swipes to invalidate" do
    log_in_manager
    employee = create_employee
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 45), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )

    patch admin_correction_path(correction), params: {
      swipe_correction: {
        employee_id: employee.id,
        day: "2026-07-04",
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
