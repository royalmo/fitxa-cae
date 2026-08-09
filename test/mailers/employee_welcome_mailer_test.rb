require "test_helper"

class EmployeeWelcomeMailerTest < ActionMailer::TestCase
  test "welcome email includes first login instructions" do
    employee = create_employee(first_name: "Ada", last_name: "Soler", email: "ada@example.test")

    mail = EmployeeWelcomeMailer.welcome(employee)

    assert_equal I18n.t("employee_welcome_mailer.welcome.subject"), mail.subject
    assert_equal [ "ada@example.test" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_equal [ "rrhh@cae.cat" ], mail.reply_to
    assert_match "Hola Ada Soler", mail.text_part.body.decoded
    assert_match "selecciona \"Rebre codi\"", mail.text_part.body.decoded
    assert_match "http://example.com/", mail.text_part.body.decoded
    assert_match "La plataforma FitxaCAE", mail.text_part.body.decoded
  end
end
