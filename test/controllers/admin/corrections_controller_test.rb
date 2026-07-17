require "test_helper"

class Admin::CorrectionsControllerTest < ActionDispatch::IntegrationTest
  test "lists persisted corrections" do
    log_in_manager
    employee = create_employee(first_name: "Laia", last_name: "Font")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: {
        "request_kind" => "missing_exit",
        "requested_swipes" => [ { "kind" => "exit", "swipe_at" => Time.zone.local(2026, 7, 4, 17, 0).iso8601 } ]
      }
    )

    get admin_corrections_path

    assert_response :success
    assert_match "Laia Font", response.body
    assert_match "Sortida oblidada", response.body
  end

  test "approves a pending correction and applies requested swipes" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    old_swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 4, 8, 45), metadata: "employee_portal")
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: {
        "invalidated_swipe_ids" => [ old_swipe.id ],
        "requested_swipes" => [
          { "kind" => "entry", "swipe_at" => Time.zone.local(2026, 7, 4, 8, 5).iso8601 },
          { "kind" => "exit", "swipe_at" => Time.zone.local(2026, 7, 4, 17, 0).iso8601 }
        ]
      }
    )

    assert_difference "employee.swipes.count", 2 do
      post approve_admin_correction_path(correction)
    end

    assert_redirected_to admin_corrections_path
    correction.reload
    assert_predicate correction, :approved?
    assert_equal manager, correction.validator
    assert_predicate old_swipe.reload, :removed?
    assert employee.swipes.where(forged: true, metadata: "admin_correction:#{correction.id}").exists?(kind: "exit")
  end

  test "rejects a pending correction without changing swipes" do
    manager = create_manager
    log_in_manager(manager)
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 4),
      details: { "request_kind" => "missing_entry" }
    )

    assert_no_difference "employee.swipes.count" do
      post reject_admin_correction_path(correction)
    end

    assert_redirected_to admin_corrections_path
    correction.reload
    assert_predicate correction, :rejected?
    assert_equal manager, correction.validator
  end

  test "does not review an already reviewed correction twice" do
    log_in_manager
    employee = create_employee
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 4)
    )

    post reject_admin_correction_path(correction)

    assert_redirected_to admin_corrections_path
    assert_equal I18n.t("admin.flash.correction_already_reviewed"), flash[:alert]
    assert_predicate correction.reload, :approved?
  end
end
