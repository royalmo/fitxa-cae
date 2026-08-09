require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "renders real dashboard metrics and recent activity" do
    manager = create_manager
    log_in_manager(manager)

    travel_to Time.zone.local(2030, 7, 4, 10, 0) do
      working_employee = create_employee(
        first_name: "Jana",
        last_name: "Soler",
        national_id: valid_dni(42_500_001)
      )
      closed_employee = create_employee(
        first_name: "Nil",
        last_name: "Serra",
        national_id: valid_dni(42_500_002)
      )
      inactive_employee = create_employee(
        first_name: "Ona",
        last_name: "Costa",
        national_id: valid_dni(42_500_003),
        active: false
      )
      working_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2030, 7, 4, 9, 58), metadata: "employee_portal")
      closed_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2030, 7, 4, 8, 0), metadata: "employee_portal")
      closed_employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2030, 7, 4, 9, 0), metadata: "employee_portal")
      closed_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2030, 6, 15, 8, 0), metadata: "employee_portal")
      closed_employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2030, 6, 15, 10, 0), metadata: "employee_portal")
      inactive_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2030, 7, 4, 9, 30), metadata: "employee_portal")
      working_employee.swipe_corrections.create!(
        requester: working_employee,
        status: :pending,
        day: Date.current,
        details: {
          "invalidated_swipe_ids" => [],
          "requested_swipes" => [ { "kind" => "exit", "hour" => 1.hour.from_now.strftime("%H:%M:%S") } ]
        }
      )
      DailyStatistic.create!(
        snapshot_at: Date.new(2030, 7, 3),
        active_user_count: 7,
        pending_correction_count: 2,
        people_worked: 5
      )
      AuditAction.create!(
        author: manager,
        recipient: working_employee,
        kind: "employee.updated",
        created_at: Time.zone.local(2030, 7, 4, 9, 15),
        updated_at: Time.zone.local(2030, 7, 4, 9, 15)
      )

      get admin_root_path
    end

    assert_response :success
    assert_select "h1", text: "Hola, Laia Riera."
    assert_select "div.d-flex.align-items-center.gap-2.mb-4 > svg.icon.text-primary + h1", text: "Hola, Laia Riera."
    assert_select "a.stat-card.admin-stat-card-link", count: 4
    assert_select "a.stat-card[href='#{admin_employees_path}']" do
      assert_select "span", text: "Treballant"
      assert_select ".display-6", text: "1/2"
      assert_select ".small.text-primary", count: 0
    end
    assert_select "a.stat-card[href='#{admin_corrections_path(status: "pending")}']" do
      assert_select "span", text: "Correccions pendents"
      assert_select ".display-6", text: "1"
    end
    assert_select "a.stat-card[href='#{admin_swipes_path(month: 7, year: 2030)}']" do
      assert_select "span", text: "Hores del mes"
      assert_select ".display-6", text: "1 h"
    end
    assert_select "a.stat-card[href='#{admin_calendars_path(year: 2030)}']" do
      assert_select "span", text: "Hores de l'any"
      assert_select ".display-6", text: "3 h"
    end
    assert_select "#adminDashboardTabs[role='tablist']" do
      assert_select "button.nav-link.active[aria-selected='true']", text: "Persones actives"
      assert_select "button.nav-link", text: "Correccions pendents"
      assert_select "button.nav-link", text: "Activitat recent"
    end
    active_panel = css_select("#admin-dashboard-active-people").first
    preloaded_data = JSON.parse(active_panel["data-dashboard-statistics-preloaded"])
    assert_equal "active_user_count", active_panel["data-dashboard-statistics-metric"]
    assert_equal "Persones actives", preloaded_data["label"]
    assert_equal [ "3/7/2030" ], preloaded_data["labels"]
    assert_equal [ 7 ], preloaded_data["values"]
    assert_select "#admin-dashboard-active-people input.btn-check[value='60d'][checked='checked'] + label", text: "60 dies"
    assert_select "#admin-dashboard-active-people input.btn-check[value='1y'] + label", text: "1 any"
    assert_select "#admin-dashboard-active-people input.btn-check[value='total'] + label", text: "Total"
    assert_select "#admin-dashboard-recent-activity table" do
      assert_select "th", text: "Fet per"
      assert_select "th", text: "Data"
      assert_select "th", text: "Acció"
      assert_select "td", text: "Laia Riera"
      assert_select "td.text-nowrap", text: "4/7/2030 09:15"
      assert_select "td", text: "Persona actualitzada"
    end
    assert_select "a[href='#{admin_audit_actions_path}']", text: "Veure activitat"
    assert_no_match "Hora sol·licitada", response.body
  end

  test "returns dashboard statistic chart data for the requested period" do
    manager = create_manager
    log_in_manager(manager)

    travel_to Time.zone.local(2030, 7, 4, 10, 0) do
      DailyStatistic.create!(
        snapshot_at: Date.new(2030, 7, 3),
        active_user_count: 7,
        pending_correction_count: 2,
        people_worked: 5
      )
      DailyStatistic.create!(
        snapshot_at: Date.new(2029, 1, 1),
        active_user_count: 4,
        pending_correction_count: 9,
        people_worked: 3
      )

      get admin_dashboard_statistics_path, params: { metric: "pending_correction_count", period: "60d" }
    end

    assert_response :success
    chart_data = JSON.parse(response.body)
    assert_equal "pending_correction_count", chart_data["metric"]
    assert_equal "60d", chart_data["period"]
    assert_equal "Correccions pendents", chart_data["label"]
    assert_equal [ "3/7/2030" ], chart_data["labels"]
    assert_equal [ 2 ], chart_data["values"]
  end
end
