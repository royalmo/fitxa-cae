require "test_helper"

class Admin::CalendarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders year calendar with status colors and correction links" do
    employee = create_employee(first_name: "Jana", last_name: "Sol")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 1, 2, 8, 0), metadata: "employee_portal")
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 1, 2, 16, 0), metadata: "employee_portal")
    pending_correction = employee.swipe_corrections.create!(requester: employee, status: :pending, day: Date.new(2026, 1, 3))
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 1, 4, 8, 0), metadata: "employee_portal")

    get admin_calendars_path, params: { employee_id: employee.id, year: "2026" }

    assert_response :success
    assert_select "h1", text: "Calendaris"
    assert_select "#employee_id option[selected][value='#{employee.id}']"
    assert_select ".admin-calendar-day.is-success-2[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-01-02")}']", text: "2"
    assert_select ".admin-calendar-day.is-warning[href='#{edit_admin_correction_path(pending_correction)}']", text: "3"
    assert_select ".admin-calendar-day.is-danger[href='#{new_admin_correction_path(employee_id: employee.id, day: "2026-01-04")}']", text: "4"
  end

  test "falls back to the current year for invalid year params" do
    create_employee

    get admin_calendars_path, params: { year: "bad" }

    assert_response :success
    assert_select "input[type='number'][value='#{Time.zone.today.year}']"
  end
end
