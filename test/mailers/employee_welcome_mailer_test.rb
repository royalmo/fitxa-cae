require "test_helper"

class EmployeeWelcomeMailerTest < ActionMailer::TestCase
  test "welcome email includes one month password setup link" do
    employee = create_employee(first_name: "Ada", last_name: "Soler", email: "ada@example.test")

    mail = EmployeeWelcomeMailer.welcome(employee)

    assert_equal I18n.t("employee_welcome_mailer.welcome.subject", app_name: Rails.configuration.x.app_name), mail.subject
    assert_equal [ "ada@example.test" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_equal [ "rrhh@cae.cat" ], mail.reply_to
    assert_match "Hola Ada Soler", mail.text_part.body.decoded
    assert_match "crea la teva contrasenya", mail.text_part.body.decoded
    assert_match "1 mes", mail.text_part.body.decoded
    assert_equal employee, Employee.find_by_password_setup_token(token_from_mail(mail))
    assert_no_match "Rebre codi", mail.text_part.body.decoded
    assert_match "La plataforma FitxaCAE", mail.text_part.body.decoded

    html_body = mail.html_part.body.decoded
    assert_no_match %r{<style\b}, html_body
    assert_match "Crea la contrasenya", html_body
    assert_match "Si el botó no funciona", html_body
    assert_match "overflow-wrap: anywhere", html_body
  end

  test "html email inlines logo dimensions for local brand image" do
    employee = create_employee(first_name: "Ada", last_name: "Soler", email: "ada@example.test")

    with_app_brand(name: "FitxaCAE", slug: "fitxa-cae", brand_suffix_image: "cae_logo.png") do
      mail = EmployeeWelcomeMailer.welcome(employee)
      html_body = mail.html_part.body.decoded

      assert_no_match %r{<style\b}, html_body
      assert_match %r{<img[^>]+height="30"[^>]+width="47"[^>]+src="cid:}, html_body
      assert_match "display: inline-block", html_body
      assert mail.attachments["cae_logo.png"].inline?
    end
  end

  private

  def token_from_mail(mail)
    mail.text_part.body.decoded.match(%r{/password-setup/(\S+)})[1]
  end
end
