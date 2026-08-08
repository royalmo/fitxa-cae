require "test_helper"
require "stringio"

class DevelopmentConsoleMailDeliveryTest < ActiveSupport::TestCase
  test "writes delivered text email details to console output once" do
    employee = create_employee(email: "ada@example.test")
    log_output = StringIO.new
    console_output = StringIO.new
    logger = ActiveSupport::Logger.new(log_output)
    mail = EmployeeLoginMailer.code(employee, "123456")

    DevelopmentConsoleMailDelivery.new(logger: logger, output: console_output).deliver!(mail)

    assert_empty log_output.string
    assert_equal 1, console_output.string.scan("Development email delivery").size
    assert_includes console_output.string, "From: from@example.com"
    assert_includes console_output.string, "To: ada@example.test"
    assert_includes console_output.string, "Subject: Codi d'accés a Fitxa CAE"
    assert_includes console_output.string, "123456"
    assert_not_includes console_output.string, "Cc:"
    assert_not_includes console_output.string, "Bcc:"
    assert_not_includes console_output.string, "Reply-To:"
    assert_not_includes console_output.string, "Content-Type:"
    assert_not_includes console_output.string, "<p>"
  end

  test "writes optional recipient headers when present" do
    console_output = StringIO.new
    logger = ActiveSupport::Logger.new(StringIO.new)
    mail = Mail.new do
      from "from@example.test"
      to "to@example.test"
      cc "cc@example.test"
      bcc "bcc@example.test"
      reply_to "reply@example.test"
      subject "Optional headers"
      body "Only text"
    end

    DevelopmentConsoleMailDelivery.new(logger: logger, output: console_output).deliver!(mail)

    assert_includes console_output.string, "Cc: cc@example.test"
    assert_includes console_output.string, "Bcc: bcc@example.test"
    assert_includes console_output.string, "Reply-To: reply@example.test"
    assert_includes console_output.string, "Subject: Optional headers"
  end

  test "falls back to html body when text body is absent" do
    console_output = StringIO.new
    logger = ActiveSupport::Logger.new(StringIO.new)
    mail = Mail.new do
      from "from@example.test"
      to "to@example.test"
      content_type "text/html; charset=UTF-8"
      body "<p>Only HTML</p>"
    end

    DevelopmentConsoleMailDelivery.new(logger: logger, output: console_output).deliver!(mail)

    assert_includes console_output.string, "<p>Only HTML</p>"
  end
end
