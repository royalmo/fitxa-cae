require "test_helper"

class HumanResourcesContactMailerTest < ActionMailer::TestCase
  test "message sends employee contact to configured human resources recipient" do
    employee = create_employee(
      email: "ada@example.test",
      phone: "+34 600 111 222"
    )

    mail = HumanResourcesContactMailer.contact_request(
      employee,
      subject: "Consulta de vacances",
      body: "Necessito parlar amb RRHH."
    )

    assert_equal "[FitxaCAE] Consulta de vacances", mail.subject
    assert_equal [ Rails.configuration.x.human_resources_email ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_equal [ "ada@example.test" ], mail.reply_to
    assert_match "S'ha rebut un nou missatge des de FitxaCAE", mail.body.encoded
    assert_match "Ada Soler", mail.body.encoded
    assert_match employee.national_id, mail.body.encoded
    assert_match "Necessito parlar amb RRHH.", mail.body.encoded
  end

  test "falls back to human resources reply-to when employee email is blank" do
    employee = create_employee(email: nil)

    mail = HumanResourcesContactMailer.contact_request(
      employee,
      subject: "Consulta",
      body: "Necessito parlar amb RRHH."
    )

    assert_equal [ "rrhh@cae.cat" ], mail.reply_to
  end
end
