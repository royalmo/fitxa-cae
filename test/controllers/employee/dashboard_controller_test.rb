require "test_helper"

class Employee::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows the signed in employees current clocking state" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 5), metadata: "employee_portal")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "exit", "hour" => "17:00:00" } ]
      }
    )
    2.times do |index|
      employee.swipe_corrections.create!(
        requester: employee,
        status: :approved,
        day: Date.new(2026, 7, 3 + index),
        details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
      )
    end
    employee.swipe_corrections.create!(
      requester: employee,
      status: :rejected,
      day: Date.new(2026, 7, 5),
      details: { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get root_path
    end

    assert_response :success
    assert_select "main.employee-main.today-main"
    assert_select "h1.page-title", text: "Hola, Ada"
    assert_select ".today-intro .page-title .icon", 0
    assert_select ".today-date time[datetime='2026-07-02']", text: "Dijous, 2 de juliol de 2026"
    assert_select ".today-intro-meta", 0
    assert_select ".today-total", 0
    assert_select ".clock-time", 0
    assert_select ".today-punch-button.is-active[data-controller='punch-timer'][data-punch-timer-base-seconds-value='0'][data-punch-timer-started-at-value]"
    assert_select ".today-punch-button.is-active .icon[aria-hidden='true']"
    assert_select ".today-punch-button.is-active .today-punch-action-row .today-punch-label", text: "Sortir"
    assert_select ".today-punch-button.is-active .today-punch-duration-number.is-hours[data-punch-timer-target='hours']", text: "0"
    assert_select ".today-punch-button.is-active .today-punch-duration-number[data-punch-timer-target='minutes']", text: "00"
    assert_select ".today-punch-button.is-active .today-punch-duration-number[data-punch-timer-target='seconds']", text: "00"
    assert_select ".today-punch-button.is-active .today-punch-duration-unit", text: "h"
    assert_select ".today-punch-button.is-active .today-punch-duration-unit", text: "m"
    assert_select ".today-punch-button.is-active .today-punch-duration-unit", text: "s"
    assert_select ".today-section-header h2", text: "Fitxatges d'avui"
    assert_select ".today-section-rule", 2
    assert_select ".today-history-row", 0
    assert_select ".today-history-label", 0
    assert_select ".today-clockings-section .clocking-hours", 0
    assert_equal %w[08:05 17:00], css_select(".today-swipe-list .clocking-swipe").map { |swipe| swipe.text.squish }
    assert_select ".clocking-swipe.is-entry", text: "08:05"
    assert_select ".clocking-swipe.is-pending-requested", text: "17:00"
    assert_select ".clocking-swipe.is-exit.is-pending-requested", text: "17:00"
    assert_select "a.today-correction-link[href='#{new_correction_path(day: "2026-07-02")}']", text: "Corregir"
    assert_select ".today-clockings-section > .today-section-header .today-section-heading-row > a.today-correction-link"
    assert_select ".today-section-header h2", text: "Resum setmanal"
    assert_select ".today-week-lines dt", text: "Activitat"
    assert_select ".today-week-lines dt a[href='#{clockings_path(month: 7, year: 2026)}']", text: "Activitat"
    assert_select ".today-week-lines dd a[href='#{clockings_path(month: 7, year: 2026)}']", text: "0 h 00 min en 1 dia"
    assert_select ".today-week-lines dt", text: "Correccions"
    assert_select ".today-week-lines dt a[href='#{corrections_path(month: 7, year: 2026)}']", text: "Correccions"
    assert_select ".today-week-lines dd a[href='#{corrections_path(month: 7, year: 2026, status: "pending")}']", text: "1 pendent"
    assert_select ".today-week-lines dd a[href='#{corrections_path(month: 7, year: 2026, status: "approved")}']", text: "2 aprovades"
    assert_select ".today-week-lines dd a[href='#{corrections_path(month: 7, year: 2026, status: "rejected")}']", text: "1 rebutjada"
    assert_no_match "0 rebutjades", response.body
    assert_select ".request-row", 0
    assert_no_match "Últim fitxatge", response.body
    assert_no_match "Correcció pendent", response.body
  end

  test "shows empty today message and pending correction summary when no swipes exist" do
    employee = create_employee(password: "1234")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [
          { "kind" => "entry", "hour" => "08:10:00" },
          { "kind" => "exit", "hour" => "17:05:00" }
        ]
      }
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get root_path
    end

    assert_response :success
    assert_select ".today-punch-button.is-active[data-punch-timer-base-seconds-value='0'][data-punch-timer-started-at-value]"
    assert_select ".today-punch-button.is-active .today-punch-label", text: "Sortir"
    assert_select ".today-history-empty em", text: "Encara no hi ha fitxatges per avui."
    assert_select ".today-swipe-list .clocking-swipe.is-entry.is-pending-requested", text: "08:10"
    assert_select ".today-swipe-list .clocking-swipe.is-exit.is-pending-requested", text: "17:05"
  end

  test "clock button treats a pending invalidated entry as already removed" do
    employee = create_employee(password: "1234")
    entry = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 5), metadata: "employee_portal")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [ entry.id ],
        "requested_swipes" => []
      }
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get root_path
    end

    assert_response :success
    assert_select ".today-punch-button.is-active", 0
    assert_select "form.today-punch-action-form[action='#{clock_in_path}'] .today-punch-button[data-punch-timer-base-seconds-value='0']"
    assert_select ".today-punch-button .today-punch-label", text: "Entrar"
    assert_select ".today-swipe-list .clocking-swipe.is-entry.is-pending-invalidated", text: "08:05"
  end

  test "clock button treats pending requested exits before now as already applied" do
    employee = create_employee(password: "1234")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [],
        "requested_swipes" => [ { "kind" => "exit", "hour" => "09:00:00" } ]
      }
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get root_path
    end

    assert_response :success
    assert_select ".today-punch-button.is-active", 0
    assert_select "form.today-punch-action-form[action='#{clock_in_path}'] .today-punch-button[data-punch-timer-base-seconds-value='3600']"
    assert_select ".today-punch-button .today-punch-label", text: "Entrar"
    assert_select ".today-punch-duration-number.is-hours", text: "1"
    assert_select ".today-punch-duration-number[data-punch-timer-target='minutes']", text: "00"
    assert_select ".today-swipe-list .clocking-swipe.is-exit.is-pending-requested", text: "09:00"
  end
end
