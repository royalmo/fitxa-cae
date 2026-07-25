require "test_helper"

class Admin::AuditActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @manager = create_manager(email: "admin.audit@example.test")
    log_in_manager(@manager)
  end

  test "lists audit actions" do
    employee = create_employee(first_name: "Iu", last_name: "Bosch")
    AuditAction.create!(
      author: @manager,
      recipient: employee,
      kind: "employee.updated",
      extra_info: { "field" => "active" }
    )

    get admin_audit_actions_path, params: { kind: "employee.updated" }

    assert_response :success
    assert_match "employee.updated", response.body
    assert_match "Iu Bosch", response.body
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select "a[href='#{export_admin_audit_actions_path(kind: "employee.updated")}'] svg.icon"
  end

  test "exports audit actions as csv" do
    employee = create_employee(first_name: "Iu", last_name: "Bosch")
    AuditAction.create!(author: @manager, recipient: employee, kind: "employee.updated")

    get export_admin_audit_actions_path

    assert_response :success
    assert_includes response.media_type, "text/csv"
    assert_match "employee.updated", response.body
    assert_match "Iu Bosch", response.body
  end
end
