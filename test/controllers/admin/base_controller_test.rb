require "test_helper"

class Admin::BaseControllerTest < ActionDispatch::IntegrationTest
  test "requires manager login for admin root without alert" do
    get admin_root_path

    assert_redirected_to admin_login_path
    assert_nil flash[:alert]
  end

  test "requires manager login for admin subpages with alert" do
    get admin_employees_path

    assert_redirected_to admin_login_path
    assert_equal I18n.t("admin.sessions.flash.require_login"), flash[:alert]
  end

  test "caps pending corrections badge in admin topbar" do
    employee = create_employee
    100.times do |index|
      employee.swipe_corrections.create!(
        requester: employee,
        status: :pending,
        day: Date.new(2026, 1, 1) + index.days
      )
    end
    log_in_manager
    pending_corrections_count = SwipeCorrection.pending.count

    get admin_root_path

    assert_response :success
    assert_operator pending_corrections_count, :>, 99
    assert_select "a.admin-topbar-corrections-button[aria-label='#{I18n.t("admin.topbar.pending_corrections", count: pending_corrections_count)}'] .admin-topbar-count-badge",
      text: "99+"
  end

  test "shows working indicator when linked employee is clocked in" do
    employee = create_employee
    manager = create_manager(employee: employee)
    employee.swipes.create!(
      kind: :entry,
      swipe_at: Time.zone.local(2026, 7, 2, 8, 0),
      metadata: "employee_portal"
    )
    log_in_manager(manager)

    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get admin_root_path
    end

    assert_response :success
    assert_select "a.admin-topbar-employee-button.is-working[href='#{root_path}'] .admin-topbar-working-dot"
  end

  test "does not show employee shortcut for linked inactive employee" do
    employee = create_employee(active: false)
    manager = create_manager(employee: employee)
    log_in_manager(manager)

    get admin_root_path

    assert_response :success
    assert_select "a.admin-topbar-employee-button[href='#{root_path}']", false
  end

  test "working indicator uses pending correction adjusted clock state" do
    employee = create_employee
    manager = create_manager(employee: employee)
    entry = employee.swipes.create!(
      kind: :entry,
      swipe_at: Time.zone.local(2026, 7, 2, 8, 0),
      metadata: "employee_portal"
    )
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "invalidated_swipe_ids" => [ entry.id ],
        "requested_swipes" => []
      }
    )
    log_in_manager(manager)

    travel_to Time.zone.local(2026, 7, 2, 10, 0) do
      get admin_root_path
    end

    assert_response :success
    assert_select "a.admin-topbar-employee-button.is-working", 0
    assert_select "a.admin-topbar-employee-button[href='#{root_path}'] .admin-topbar-working-dot", 0
  end
end
