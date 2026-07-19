require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "renders real dashboard metrics and recent activity" do
    manager = create_manager
    log_in_manager(manager)

    travel_to Time.zone.local(2030, 7, 4, 10, 0) do
      employee = create_employee(first_name: "Jana", last_name: "Soler")
      employee.swipes.create!(kind: :entry, swipe_at: 2.minutes.ago, metadata: "employee_portal")
      employee.swipe_corrections.create!(
        requester: employee,
        status: :pending,
        day: Date.current,
        details: {
          "request_kind" => "missing_exit",
          "requested_swipes" => [ { "kind" => "exit", "swipe_at" => 1.hour.from_now.iso8601 } ]
        }
      )

      get admin_root_path
    end

    assert_response :success
    assert_select ".stat-card", minimum: 4
    assert_match "Jana Soler", response.body
    assert_match "Hora sol·licitada", response.body
  end
end
