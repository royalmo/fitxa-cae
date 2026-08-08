require "test_helper"

class Admin::EmployeeBulkActionRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @manager = create_manager(email: "bulk.status@example.test")
    log_in_manager(@manager)
  end

  test "shows queued run status" do
    employee_bulk_action_run = @manager.employee_bulk_action_runs.create!(
      kind: "activation",
      parameters: { action: "activate", national_ids: [ valid_dni(48_200_001) ] }
    )

    get admin_employee_bulk_action_run_path(employee_bulk_action_run)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal employee_bulk_action_run.id, payload.fetch("id")
    assert_equal "activation", payload.fetch("kind")
    assert_equal "queued", payload.fetch("status")
    assert_equal 0, payload.fetch("progress")
    assert_equal "Acció en cua...", payload.fetch("message")
    assert_equal admin_employee_bulk_action_run_path(employee_bulk_action_run), payload.fetch("status_url")
  end

  test "shows completed result message" do
    employee_bulk_action_run = @manager.employee_bulk_action_runs.create!(
      kind: "tags",
      status: :completed,
      progress: 100,
      result_message: "Etiquetes actualitzades.",
      parameters: { national_ids: [ valid_dni(48_200_002) ], add_tag_ids: [], remove_tag_ids: [], include_inactive: false }
    )

    get admin_employee_bulk_action_run_path(employee_bulk_action_run)

    assert_response :success
    assert_equal "Etiquetes actualitzades.", JSON.parse(response.body).fetch("message")
  end

  test "does not expose another manager run" do
    other_manager = create_manager(email: "other.bulk.status@example.test")
    employee_bulk_action_run = other_manager.employee_bulk_action_runs.create!(
      kind: "activation",
      parameters: { action: "activate", national_ids: [ valid_dni(48_200_003) ] }
    )

    get admin_employee_bulk_action_run_path(employee_bulk_action_run)

    assert_response :not_found
  end
end
