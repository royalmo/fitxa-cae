require "test_helper"

class AuditActionTest < ActiveSupport::TestCase
  test "requires author recipient and kind" do
    audit_action = AuditAction.new

    assert_not audit_action.valid?
    assert_model_error audit_action, :author, :blank
    assert_model_error audit_action, :recipient, :blank
    assert_model_error audit_action, :kind, :blank
  end

  test "supports polymorphic author and recipient" do
    employee = create_employee
    manager = create_manager
    audit_action = AuditAction.create!(
      author: manager,
      recipient: employee,
      kind: "swipe_correction.approved",
      extra_info: { "source" => "admin" }
    )

    assert_equal manager, audit_action.author
    assert_equal employee, audit_action.recipient
    assert_equal({ "source" => "admin" }, audit_action.extra_info)
  end
end
