require "test_helper"

class ProcessEmployeeBulkActionRunJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "processes activation runs" do
    manager = create_manager
    employee = create_employee(national_id: valid_dni(48_100_001), active: false)
    employee_bulk_action_run = manager.employee_bulk_action_runs.create!(
      kind: "activation",
      parameters: { action: "activate", national_ids: [ employee.national_id ] }
    )

    ProcessEmployeeBulkActionRunJob.perform_now(employee_bulk_action_run)

    assert_predicate employee.reload, :active?
    assert_predicate employee_bulk_action_run.reload, :completed?
    assert_equal 100, employee_bulk_action_run.progress
    assert_equal "S'ha activat 1 persona.", employee_bulk_action_run.result_message
  end

  test "processes import runs and enqueues welcome delivery" do
    manager = create_manager
    national_id = valid_dni(48_100_002)
    employee_bulk_action_run = manager.employee_bulk_action_runs.create!(
      kind: "import",
      parameters: {
        source: "paste",
        content: "Name,Surname,DNI/NIE,email,phone\nAda,Soler,#{national_id},ada@example.test,600 111 222\n",
        allow_second_surname: false,
        tag_ids: []
      }
    )

    assert_difference -> { Employee.count }, 1 do
      ProcessEmployeeBulkActionRunJob.perform_now(employee_bulk_action_run)
    end

    assert_predicate employee_bulk_action_run.reload, :completed?
    assert_equal "S'ha importat 1 persona.", employee_bulk_action_run.result_message
    assert_equal "ada@example.test", Employee.find_by!(national_id: national_id).email
    assert_enqueued_jobs 1, only: EmployeeWelcomeDeliveryJob
  end

  test "marks expected stale runs failed without reporting an unexpected error" do
    manager = create_manager
    employee = create_employee(national_id: valid_dni(48_100_003), active: true)
    employee_bulk_action_run = manager.employee_bulk_action_runs.create!(
      kind: "activation",
      parameters: { action: "activate", national_ids: [ employee.national_id ] }
    )

    with_error_notifications do |notifications|
      ProcessEmployeeBulkActionRunJob.perform_now(employee_bulk_action_run)

      assert_empty notifications
    end

    assert_predicate employee_bulk_action_run.reload, :failed?
    assert_equal "Aquesta acció no afectarà cap persona.", employee_bulk_action_run.error_message
  end
end
