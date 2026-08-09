require "test_helper"

class ManagerPasswordMailerTest < ActionMailer::TestCase
  test "password setup email includes one month setup link" do
    manager = create_manager(first_name: "Laia", last_name: "Riera", email: "laia.riera@example.test", password: nil)

    mail = ManagerPasswordMailer.password_setup(manager)

    assert_equal I18n.t("manager_password_mailer.password_setup.subject"), mail.subject
    assert_equal [ "laia.riera@example.test" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_equal [ "rrhh@cae.cat" ], mail.reply_to
    assert_match "S'ha creat el teu compte", mail.text_part.body.decoded
    assert_match "crea la teva contrasenya", mail.text_part.body.decoded
    assert_equal manager, Manager.find_by_password_setup_token(token_from_mail(mail))
    assert_match "1 mes", mail.text_part.body.decoded
    assert_match "La plataforma FitxaCAE", mail.text_part.body.decoded

    html_body = mail.html_part.body.decoded
    assert_match "Crea la contrasenya", html_body
    assert_match "Si el botó no funciona", html_body
    assert_match "mailer-fallback-link", html_body
    assert_no_match %r{class="mailer-button"[^>]*>https?://}, html_body
  end

  test "password reset email includes one hour reset link" do
    manager = create_manager(first_name: "Laia", last_name: "Riera", email: "laia.riera@example.test", password: "12345678")

    mail = ManagerPasswordMailer.password_reset(manager)

    assert_equal I18n.t("manager_password_mailer.password_reset.subject"), mail.subject
    assert_equal [ "laia.riera@example.test" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_equal [ "rrhh@cae.cat" ], mail.reply_to
    assert_match "restablir la contrasenya", mail.text_part.body.decoded
    assert_equal manager, Manager.find_by_password_reset_token(token_from_mail(mail))
    assert_match "1 hora", mail.text_part.body.decoded
    assert_match "Si no has estat tu", mail.text_part.body.decoded
    assert_match "La plataforma FitxaCAE", mail.text_part.body.decoded

    html_body = mail.html_part.body.decoded
    assert_match "Canviar contrasenya", html_body
    assert_match "Si el botó no funciona", html_body
    assert_match "mailer-fallback-link", html_body
    assert_no_match %r{class="mailer-button"[^>]*>https?://}, html_body
  end

  private

  def token_from_mail(mail)
    mail.text_part.body.decoded.match(%r{/admin/password-reset/(\S+)})[1]
  end
end
