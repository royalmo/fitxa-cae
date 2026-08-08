require "test_helper"

class EmployeeBulkActionRunTest < ActiveSupport::TestCase
  test "defaults to queued with zero progress" do
    employee_bulk_action_run = create_manager.employee_bulk_action_runs.create!(
      kind: "activation",
      parameters: { action: "activate", national_ids: [ valid_dni(48_000_001) ] }
    )

    assert_predicate employee_bulk_action_run, :queued?
    assert_equal 0, employee_bulk_action_run.progress
  end

  test "marks completed and failed runs" do
    employee_bulk_action_run = create_manager.employee_bulk_action_runs.create!(
      kind: "tags",
      parameters: { national_ids: [ valid_dni(48_000_002) ], add_tag_ids: [], remove_tag_ids: [], include_inactive: false }
    )

    employee_bulk_action_run.mark_completed!("Acció completada.")

    assert_predicate employee_bulk_action_run, :completed?
    assert_predicate employee_bulk_action_run, :terminal?
    assert_equal 100, employee_bulk_action_run.progress
    assert_equal "Acció completada.", employee_bulk_action_run.result_message

    employee_bulk_action_run.mark_failed!("Error")

    assert_predicate employee_bulk_action_run, :failed?
    assert_equal "Error", employee_bulk_action_run.error_message
  end
end
