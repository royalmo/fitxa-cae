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
        "request_kind" => "missing_exit",
        "requested_swipes" => [ { "kind" => "exit", "swipe_at" => Time.zone.local(2026, 7, 2, 17, 0).iso8601 } ]
      }
    )

    log_in_employee(employee)
    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get root_path
    end

    assert_response :success
    assert_select "h1", text: "Hola, Ada"
    assert_select ".clock-time", text: "08:05"
    assert_select ".timeline strong", text: "Entrada"
    assert_select ".request-row", text: /Sortida oblidada/
  end
end
