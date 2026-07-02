require "test_helper"

class Employee::CorrectionsControllerTest < ActionDispatch::IntegrationTest
  test "creates a pending swipe correction for the signed in employee" do
    employee = create_employee(password: "1234")
    swipe = employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 8, 40), metadata: "employee_portal")
    log_in_employee(employee)

    assert_difference "SwipeCorrection.count", 1 do
      post corrections_path, params: {
        date: "2026-07-02",
        kind: "wrong_entry",
        time: "08:05",
        note: "Vaig entrar abans.",
        invalidated_swipe_ids: [ swipe.id ]
      }
    end

    assert_redirected_to corrections_path
    correction = employee.swipe_corrections.last
    assert_equal "pending", correction.status
    assert_equal employee, correction.requester
    assert_equal Date.new(2026, 7, 2), correction.day
    assert_equal "wrong_entry", correction.details["request_kind"]
    assert_equal [ swipe.id ], correction.details["invalidated_swipe_ids"]
    assert_equal "entry", correction.details["requested_swipes"].first["kind"]
    assert_equal "Vaig entrar abans.", correction.requester_comments
  end

  test "rejects incomplete correction requests" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    assert_no_difference "SwipeCorrection.count" do
      post corrections_path, params: {
        date: "",
        kind: "not-supported",
        time: "",
        note: "Sense dades"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error-summary"
  end

  test "lists corrections from the signed in employee" do
    employee = create_employee(password: "1234")
    other_employee = create_employee(national_id: valid_dni(12_345_679), password: "1234")
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: {
        "request_kind" => "missing_exit",
        "requested_swipes" => [ { "kind" => "exit", "swipe_at" => Time.zone.local(2026, 7, 2, 17, 0).iso8601 } ]
      },
      requester_comments: "Sortida oblidada"
    )
    other_employee.swipe_corrections.create!(
      requester: other_employee,
      status: :pending,
      day: Date.new(2026, 7, 2),
      details: { "request_kind" => "missing_entry" },
      requester_comments: "No visible"
    )

    log_in_employee(employee)
    get corrections_path

    assert_response :success
    assert_match "Sortida oblidada", response.body
    assert_no_match "No visible", response.body
  end
end
