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

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get root_path
    end

    assert_response :success
    assert_select "h1.page-title", text: "Avui"
    assert_select ".today-intro-meta", text: /Hola, Ada/
    assert_select ".clock-time", text: "08:05"
    assert_select ".today-clock-panel.is-clocked-in"
    assert_select ".today-clock-action.danger", text: "Sortir"
    assert_select ".today-timeline-item strong", text: "Entrada"
    assert_select ".today-metric-list", text: /Correccions/
    assert_select ".today-metric-list dd", text: "1"
    assert_select ".request-row", 0
    assert_no_match "Correcció pendent", response.body
    assert_no_match "Sortida 17:00", response.body
  end
end
