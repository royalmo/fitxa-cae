require "test_helper"

class ProcessEmployeeBulkActionRunJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
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

  test "processes import runs and delivers welcome emails" do
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

    assert_no_enqueued_jobs only: EmployeeWelcomeDeliveryJob do
      assert_difference -> { Employee.count }, 1 do
        assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
          ProcessEmployeeBulkActionRunJob.perform_now(employee_bulk_action_run)
        end
      end
    end

    assert_predicate employee_bulk_action_run.reload, :completed?
    assert_equal "S'ha importat 1 persona.", employee_bulk_action_run.result_message
    assert_equal "ada@example.test", Employee.find_by!(national_id: national_id).email
  end

  test "updates import progress for each welcome email delivery" do
    manager = create_manager
    national_ids = [
      valid_dni(48_100_004),
      valid_dni(48_100_005),
      valid_dni(48_100_006)
    ]
    employee_bulk_action_run = manager.employee_bulk_action_runs.create!(
      kind: "import",
      parameters: {
        source: "paste",
        content: <<~CSV,
          Name,Surname,DNI/NIE,email,phone
          Ada,Soler,#{national_ids[0]},ada@example.test,600 111 222
          Laia,Riera,#{national_ids[1]},laia@example.test,600 333 444
          Ona,Prat,#{national_ids[2]},ona@example.test,600 555 666
        CSV
        allow_second_surname: false,
        tag_ids: []
      }
    )
    observed_progress = []

    with_welcome_delivery(->(_employee) {
      observed_progress << employee_bulk_action_run.reload.progress
      delivered_message
    }) do
      assert_difference -> { Employee.count }, 3 do
        ProcessEmployeeBulkActionRunJob.perform_now(employee_bulk_action_run)
      end
    end

    assert_equal 3, observed_progress.size
    assert_equal observed_progress.sort, observed_progress
    assert_equal observed_progress.uniq, observed_progress
    assert observed_progress.all? { |progress| progress.between?(1, 99) }
    assert_equal 100, employee_bulk_action_run.reload.progress
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

  private

  def with_welcome_delivery(delivery)
    singleton = class << EmployeeWelcomeMailer
      self
    end
    original_method = EmployeeWelcomeMailer.method(:welcome)

    singleton.define_method(:welcome, &delivery)
    yield
  ensure
    singleton.define_method(:welcome, original_method) if original_method
  end

  def delivered_message
    Object.new.tap do |message|
      message.define_singleton_method(:deliver_now) { }
    end
  end
end
