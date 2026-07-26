require "test_helper"

class Admin::SwipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders a full selected month without skipping empty days" do
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 16, 0), metadata: "employee_portal")

    get admin_swipes_path, params: { employee_id: employee.id, month: "2026-07" }

    assert_response :success
    assert_select "h1", text: "Fitxatges"
    assert_select "h2", text: "Filtres", count: 0
    assert_select "#employee_id option[selected][value='#{employee.id}']"
    assert_select "input[type='month'][value='2026-07']"
    assert_select "tbody tr", count: 31
    assert_match "8 h 00 min", response.body
    assert_match "Sense fitxatges", response.body
    assert_select "a.admin-row-action[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-07-01")}'] svg.icon"
  end

  test "falls back to the current month for invalid month params" do
    create_employee

    get admin_swipes_path, params: { month: "bad" }

    assert_response :success
    assert_select "input[type='month'][value='#{Time.zone.today.strftime("%Y-%m")}']"
  end
end
