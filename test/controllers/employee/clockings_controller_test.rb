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
    assert_select "td", text: "08:00"
    assert_select "td", text: "16:30"
    assert_select "strong", text: "8 h 30 min"
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
  end
end
