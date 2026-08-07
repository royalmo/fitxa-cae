require "test_helper"
require "stringio"

class DevelopmentConsoleMailDeliveryTest < ActiveSupport::TestCase
  test "writes delivered email details to the logger" do
    employee = create_employee(email: "ada@example.test")
    log_output = StringIO.new
    console_output = StringIO.new
    logger = ActiveSupport::Logger.new(log_output)
    mail = EmployeeLoginMailer.code(employee, "123456")

    DevelopmentConsoleMailDelivery.new(logger: logger, output: console_output).deliver!(mail)

    assert_includes log_output.string, "Development email delivery"
    assert_includes console_output.string, "To: ada@example.test"
    assert_includes console_output.string, "123456"
  end
end
