require "test_helper"

class ManagerPasswordMailerTest < ActionMailer::TestCase
  test "password setup email includes one month setup link" do
    manager = create_manager(first_name: "Laia", last_name: "Riera", email: "laia.riera@example.test", password: nil)

    mail = ManagerPasswordMailer.password_setup(manager)

    assert_equal I18n.t("manager_password_mailer.password_setup.subject"), mail.subject
    assert_equal [ "laia.riera@example.test" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "s'ha creat el teu compte", mail.text_part.body.decoded
    assert_equal manager, Manager.find_by_password_setup_token(token_from_mail(mail))
    assert_match "1 mes", mail.text_part.body.decoded
  end

  test "password reset email includes one hour reset link" do
    manager = create_manager(first_name: "Laia", last_name: "Riera", email: "laia.riera@example.test", password: "12345678")

    mail = ManagerPasswordMailer.password_reset(manager)

    assert_equal I18n.t("manager_password_mailer.password_reset.subject"), mail.subject
    assert_equal [ "laia.riera@example.test" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "restablir la contrasenya", mail.text_part.body.decoded
    assert_equal manager, Manager.find_by_password_reset_token(token_from_mail(mail))
    assert_match "1 hora", mail.text_part.body.decoded
  end

  private

  def token_from_mail(mail)
    mail.text_part.body.decoded.match(%r{/admin/password-reset/(\S+)})[1]
  end
end
