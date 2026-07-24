require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders monthly report rows from swipes and corrections" do
    employee = create_employee(first_name: "Oriol", last_name: "Puig")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 16, 30), metadata: "employee_portal")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2)
    )

    get admin_reports_path, params: { month: "2026-07", employee_id: employee.id }

    assert_response :success
    assert_match "Oriol Puig", response.body
    assert_match "8 h 30 min", response.body
    assert_select "td", text: "1"
    assert_select "[data-controller='list-loading']"
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select "button[type='submit'][data-submitting-label='Filtrant...'] svg.icon"
    assert_select "a[href='#']", 0
  end

  test "falls back to current month for invalid month params" do
    get admin_reports_path, params: { month: "bad" }

    assert_response :success
    assert_select "input[type='month']"
  end
end
