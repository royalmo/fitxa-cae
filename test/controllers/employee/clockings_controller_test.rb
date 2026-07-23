require "test_helper"

class Employee::ClockingsControllerTest < ActionDispatch::IntegrationTest
  test "clocking history is backed by swipes" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 16, 30), metadata: "employee_portal")

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 18, 0) do
      get clockings_path
    end

    assert_response :success
    assert_equal [ "Data", "Hores", "Fitxatges" ], css_select("thead th").map { |header| header.text.squish }
    assert_select "thead th", 3
    assert_select ".clocking-swipe", 2
    assert_select ".clocking-swipe .clocking-swipe-icon[aria-label='Entrada']"
    assert_select ".clocking-swipe .clocking-swipe-icon[aria-label='Sortida']"
    assert_select ".clocking-swipe", text: "08:00"
    assert_select ".clocking-swipe", text: "16:30"
    assert_select "a.clocking-correction-link[href='#{new_correction_path(day: "2026-07-02")}']"
    assert_select ".clocking-correction-link .clocking-correction-icon"
    assert_select ".clocking-hours", text: "8 h 30 min"
    assert_select ".clocking-hours.is-incomplete", 0
  end

  test "clocking history marks hours in primary red when the day has odd swipes" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 13, 42), metadata: "employee_portal")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 14, 30), metadata: "employee_portal")

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 18, 0) do
      get clockings_path
    end

    assert_response :success
    assert_select ".clocking-swipe", 3
    assert_select ".clocking-hours.is-incomplete", text: "5 h 42 min"
  end

  test "clocking history previews pending correction swipes in yellow" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    exit_swipe = employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 13, 0), metadata: "employee_portal")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [ exit_swipe.id ],
        "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ]
      }
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 18, 0) do
      get clockings_path
    end

    assert_response :success
    assert_select ".clocking-swipe", 3
    assert_select ".clocking-swipe:not(.is-pending-invalidated):not(.is-pending-requested)", text: "08:00"
    assert_select ".clocking-swipe.is-pending-invalidated", text: "13:00"
    assert_select ".clocking-swipe.is-pending-requested", text: "17:00"
    assert_select ".clocking-hours", text: "9 h 00 min"
    assert_select ".clocking-hours.is-incomplete", 0
  end

  test "clocking history month selector uses url params" do
    employee = nil
    travel_to Time.zone.local(2026, 5, 10, 9, 0) do
      employee = create_employee(password: "1234")
    end
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 6, 3, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 6, 3, 16, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 30), metadata: "employee_portal")

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get clockings_path, params: { month: 6, year: 2026 }
    end

    assert_response :success
    assert_select ".page-intro p", 0
    assert_select "[data-controller='list-loading']"
    assert_select "[data-list-loading-target='results']"
    assert_select ".list-loading-state[data-list-loading-target='loading'][hidden]", text: "Carregant..."
    assert_select ".clockings-intro .page-title", text: "Historial"
    assert_select ".clockings-month-controls"
    assert_select "form.clockings-month-form[action='#{clockings_path}'][method='get']"
    assert_select "#clockings_month[name='month'][data-action='change->list-loading#filter'] option[selected][value='6']"
    assert_select "#clockings_month[disabled]", 0
    assert_select "#clockings_year[name='year'][data-action='change->list-loading#filter'] option[selected][value='2026']"
    assert_select "#clockings_year[disabled]"
    assert_select "input[type='hidden'][name='year'][value='2026']"
    assert_select "a.clockings-month-arrow[href='#{clockings_path(month: 5, year: 2026)}'][aria-label='Mes anterior'][data-action='click->list-loading#navigate']"
    assert_select "a.clockings-month-arrow[href='#{clockings_path(month: 7, year: 2026)}'][aria-label='Mes següent'][data-action='click->list-loading#navigate']"
    assert_select "td", text: /3 de juny/i
    assert_select ".clocking-swipe", text: "08:00"
    assert_select ".clocking-swipe", text: "08:30", count: 0
  end

  test "clocking history renders all daily swipes in order" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 13, 42), metadata: "employee_portal")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 14, 30), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 17, 0), metadata: "employee_portal")

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 18, 0) do
      get clockings_path
    end

    assert_response :success
    assert_equal %w[08:00 13:42 14:30 17:00], css_select(".clocking-swipe").map { |swipe| swipe.text.squish }
    assert_equal [ "Entrada", "Sortida", "Entrada", "Sortida" ],
      css_select(".clocking-swipe-icon").map { |icon| icon["aria-label"] }
    assert_select ".clocking-hours", text: "8 h 12 min"
    assert_select ".clocking-hours.is-incomplete", 0
  end

  test "clocking history keeps unreachable requested months selected without rendering the table" do
    employee = nil
    travel_to Time.zone.local(2026, 6, 15, 9, 0) do
      employee = create_employee(password: "1234")
    end

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get clockings_path, params: { month: 5, year: 2026 }
    end

    assert_response :success
    assert_select "#clockings_month option[selected][disabled][value='5']"
    assert_select "#clockings_year[disabled]"
    assert_select "input[type='hidden'][name='year'][value='2026']"
    assert_select ".clockings-month-arrow.is-disabled[aria-disabled='true'][aria-label='Mes anterior']"
    assert_select "a.clockings-month-arrow[href='#{clockings_path(month: 6, year: 2026)}'][aria-label='Mes següent']"
    assert_select "table", 0
    assert_select ".clockings-empty-state .empty-state-icon"
    assert_select ".clockings-empty-state", text: /No hi ha registres per aquest mes/
    assert_select "a.clockings-current-month-link[href='#{clockings_path(month: 7, year: 2026)}'][data-action='click->list-loading#navigate']", text: "Anar al mes actual"

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get clockings_path, params: { month: 12, year: 2026 }
    end

    assert_response :success
    assert_select "#clockings_month option[selected][disabled][value='12']"
    assert_select "a.clockings-month-arrow[href='#{clockings_path(month: 7, year: 2026)}'][aria-label='Mes anterior']"
    assert_select ".clockings-month-arrow.is-disabled[aria-disabled='true'][aria-label='Mes següent']"
    assert_select "table", 0
    assert_select ".clockings-empty-state", text: /No hi ha registres per aquest mes/
    assert_select "a.clockings-current-month-link[href='#{clockings_path(month: 7, year: 2026)}']", text: "Anar al mes actual"
  end

  test "clocking history disables month selector when only one month is available" do
    employee = nil
    travel_to Time.zone.local(2025, 12, 15, 9, 0) do
      employee = create_employee(password: "1234")
    end

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 1, 19, 12, 0) do
      get clockings_path
    end

    assert_response :success
    assert_select "#clockings_month[disabled]"
    assert_select "input[type='hidden'][name='month'][value='1']"
    assert_select "#clockings_year[disabled]", 0
    assert_select ".clockings-empty-state", text: /Apareixeran aquí els fitxatges d'aquest mes/
    assert_select "a.clockings-current-month-link", 0

    travel_to Time.zone.local(2026, 1, 19, 12, 0) do
      get clockings_path, params: { year: 2025 }
    end

    assert_response :success
    assert_select "#clockings_month[disabled]"
    assert_select "input[type='hidden'][name='month'][value='12']"
    assert_select "#clockings_month option[selected][value='12']"
    assert_select "#clockings_year option[selected][value='2025']"
  end

  test "clocking history correction links only show for current and previous month days" do
    employee = nil
    travel_to Time.zone.local(2026, 5, 10, 9, 0) do
      employee = create_employee(password: "1234")
    end
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 5, 29, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 6, 3, 8, 0), metadata: "employee_portal")

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get clockings_path, params: { month: 5, year: 2026 }
    end

    assert_response :success
    assert_select "a.clocking-correction-link", 0

    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get clockings_path, params: { month: 6, year: 2026 }
    end

    assert_response :success
    assert_select "a.clocking-correction-link[href='#{new_correction_path(day: "2026-06-03")}']"
  end

  test "clocking history shows kept swipe days and pending correction days from earliest to latest" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 10, 9, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 5, 8, 30), metadata: "employee_portal", removed: true)
    employee.swipe_corrections.create!(
      day: Date.new(2026, 7, 6),
      status: :pending,
      requester: employee,
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [
          { "kind" => "entry", "hour" => "08:00:00" },
          { "kind" => "exit", "hour" => "16:00:00" }
        ]
      },
      requester_comments: "Sense fitxatges"
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 19, 12, 0) do
      get clockings_path
    end

    assert_response :success
    dates = css_select("tbody tr td:first-child").map { |cell| cell.text.squish }

    assert_equal 3, dates.length
    assert_match(/2 de juliol/i, dates.first)
    assert_match(/6 de juliol/i, dates.second)
    assert_match(/10 de juliol/i, dates.third)
    assert_no_match(/5 de juliol/i, response.body)
    assert_select ".clocking-swipe.is-pending-requested", text: "08:00"
    assert_select ".clocking-swipe.is-pending-requested", text: "16:00"
  end

  test "clock in and clock out create persisted swipes" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    travel_to Time.zone.local(2026, 7, 2, 8, 15) do
      assert_difference "employee.swipes.count", 1 do
        post clock_in_path
      end
    end

    assert_redirected_to root_path
    entry = employee.swipes.last
    assert_equal "entry", entry.kind
    assert_equal "employee_portal", entry.metadata

    assert_no_difference "employee.swipes.count" do
      post clock_in_path
    end

    travel_to Time.zone.local(2026, 7, 2, 17, 5) do
      assert_difference "employee.swipes.count", 1 do
        post clock_out_path
      end
    end

    assert_equal "exit", employee.swipes.last.kind
  end

  test "clock out without an open entry does not create a swipe" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    assert_no_difference "employee.swipes.count" do
      post clock_out_path
    end

    assert_redirected_to root_path
    assert_equal I18n.t("employee.flash.already_clocked_out"), flash[:alert]

    follow_redirect!
    assert_select ".today-intro + .employee-page-flash.dismissible-flash"
    assert_select ".employee-page-flash > span", text: I18n.t("employee.flash.already_clocked_out")
    assert_select ".employee-page-flash .flash-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
  end
end
