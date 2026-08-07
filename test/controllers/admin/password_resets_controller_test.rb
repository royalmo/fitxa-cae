require "test_helper"

class Admin::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "shows the password reset request form" do
    get new_admin_password_reset_path

    assert_response :success
    assert_select "title", text: "Restablir contrasenya | FitxaCAE Admin"
    assert_select ".admin-auth-card .auth-panel", 1
    assert_select ".auth-panel-actions .auth-back-link[href='#{admin_login_path}']", text: /Tornar/
    assert_select "form.auth-form[action='#{admin_password_reset_path}']"
    assert_select "input[name='email'][autocomplete='username'][required]"
    assert_select "input[type='submit'][data-submitting-label='Enviant...'][value='Enviar enllaç']"
  end

  test "requests a reset link for an active manager without revealing account existence" do
    manager = create_manager(email: "laia.riera@example.test", password: "12345678")

    assert_enqueued_emails 1 do
      post admin_password_reset_path, params: { email: " LAIA.RIERA@EXAMPLE.TEST " }
    end

    assert_redirected_to admin_login_path
    assert_equal I18n.t("admin.password_resets.create.sent"), flash[:notice]

    deliver_enqueued_emails
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "laia.riera@example.test" ], mail.to
    assert_equal I18n.t("manager_password_mailer.password_reset.subject"), mail.subject
    assert_equal manager, Manager.find_by_password_reset_token(token_from_mail(mail))

    assert_no_enqueued_emails do
      post admin_password_reset_path, params: { email: "missing@example.test" }
    end

    assert_redirected_to admin_login_path
    assert_equal I18n.t("admin.password_resets.create.sent"), flash[:notice]
  end

  test "does not send reset links for inactive managers" do
    create_manager(email: "inactive@example.test", password: "12345678", active: false)

    assert_no_enqueued_emails do
      post admin_password_reset_path, params: { email: "inactive@example.test" }
    end

    assert_redirected_to admin_login_path
    assert_equal I18n.t("admin.password_resets.create.sent"), flash[:notice]
  end

  test "reset link updates password and does not sign in the manager" do
    manager = create_manager(email: "laia.riera@example.test", password: "12345678")
    token = manager.password_reset_token

    get edit_admin_password_reset_path(token)

    assert_response :success
    assert_select "title", text: "Nova contrasenya | FitxaCAE Admin"
    assert_select "form.auth-form[action='#{edit_admin_password_reset_path(token)}']"
    assert_select "input[name='password'][autocomplete='new-password'][required]"
    assert_select "input[name='password_confirmation'][autocomplete='new-password'][required]"

    patch edit_admin_password_reset_path(token), params: {
      password: "new-secret",
      password_confirmation: "new-secret"
    }

    assert_redirected_to admin_login_path
    assert_equal I18n.t("admin.password_resets.update.success"), flash[:notice]
    manager.reload
    assert_not manager.authenticate_password("12345678")
    assert manager.authenticate_password("new-secret")
    assert_nil Manager.find_by_password_reset_token(token)

    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "reset link rejects mismatched passwords" do
    manager = create_manager(email: "laia.riera@example.test", password: "12345678")
    token = manager.password_reset_token

    patch edit_admin_password_reset_path(token), params: {
      password: "new-secret",
      password_confirmation: "other-secret"
    }

    assert_response :unprocessable_entity
    assert_select ".auth-panel > .error-summary.error-summary-single"
    assert_select ".error-summary-content", text: I18n.t("admin.password_resets.update.password_confirmation_invalid")
    assert manager.reload.authenticate_password("12345678")
  end

  test "invalid reset links redirect to the request form" do
    get edit_admin_password_reset_path("bad-token")

    assert_redirected_to new_admin_password_reset_path
    assert_equal I18n.t("admin.password_resets.flash.invalid_token"), flash[:alert]
  end

  test "expired reset links are rejected" do
    manager = create_manager(email: "laia.riera@example.test", password: "12345678")
    token = manager.password_reset_token

    travel Manager::PASSWORD_RESET_TOKEN_TTL + 1.second

    get edit_admin_password_reset_path(token)

    assert_redirected_to new_admin_password_reset_path
    assert_equal I18n.t("admin.password_resets.flash.invalid_token"), flash[:alert]
  end

  private

  def token_from_mail(mail)
    mail.text_part.body.decoded.match(%r{/admin/password-reset/(\S+)})[1]
  end
end
