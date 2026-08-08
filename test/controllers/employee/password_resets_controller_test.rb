require "test_helper"
require "stringio"

class Employee::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
    Employee::PasswordResetsController::CODE_REQUEST_RATE_LIMIT_STORE.clear
  end

  test "shows the password reset request form" do
    get new_employee_password_reset_path

    assert_response :success
    assert_select "title", text: "Restablir contrasenya | FitxaCAE"
    assert_select ".employee-auth-card .auth-panel", 1
    assert_select ".auth-tab-list", 0
    assert_select ".auth-panel-actions .auth-back-link[href='#{login_path}']", text: /Tornar/
    assert_select "form.auth-form[action='#{employee_password_reset_path}']"
    assert_select "input#employee_password_reset_national_id[name='national_id'][autocomplete='username'][required]"
    assert_select "#employee_password_reset_delivery_method_email[checked]"
    assert_select "#employee_password_reset_delivery_method_sms[checked]", 0
    assert_equal [ "Correu", "SMS" ], css_select(".delivery-method-options label").map { |label| label.text.squish }
    assert_select "input[type='submit'][data-submitting-label='Enviant...'][value='Enviar codi']"
  end

  test "password reset sends a code, verifies it, sets password, and signs in" do
    employee = create_employee(email: "ada@example.test", password: "1234")

    assert_enqueued_jobs 1, only: EmployeeLoginCodeDeliveryJob do
      with_secure_random_number(42) do
        post employee_password_reset_path, params: {
          national_id: employee.national_id,
          delivery_method: "email"
        }
      end
    end

    assert_redirected_to employee_password_reset_code_path
    assert_equal "email", employee.reload.settings.dig("login_code", "delivery_method")

    follow_redirect!
    assert_response :success
    assert_select "title", text: "Codi de restabliment | FitxaCAE"
    assert_select ".auth-code-help span", text: I18n.t("employee.password_resets.code.sent_if_found_intro")
    assert_select ".auth-code-help span", text: I18n.t("employee.password_resets.code.sent_if_found.email")
    assert_select ".auth-panel-actions .auth-back-link[href='#{new_employee_password_reset_path(delivery_method: "email")}']", text: /Tornar/
    assert_select "form.auth-form[action='#{verify_employee_password_reset_code_path}'][autocomplete='off'][data-controller='code-input']"
    assert_select ".code-inputs .code-digit-input", 6
    assert_select "input#password_reset_code_digit_1[name='code_digits[]']"
    assert_select "form.auth-form input[type='submit'][data-code-input-target='submit'][data-submitting-label='Continuant...'][value='Continuar']"

    post verify_employee_password_reset_code_path, params: { code: "000422" }

    assert_redirected_to edit_employee_password_reset_path
    assert_nil employee.reload.settings["login_code"]

    follow_redirect!
    assert_response :success
    assert_select "title", text: "Nova contrasenya | FitxaCAE"
    assert_select ".auth-panel > .flash-notice", count: 0
    assert_select "form.auth-form[action='#{employee_password_reset_path}']"
    assert_select "form#employee_password_setup_skip_form", count: 0
    assert_select "button", text: I18n.t("employee.password_resets.edit.skip"), count: 0
    assert_select "input[name='password'][autocomplete='new-password'][required]"
    assert_select "input[name='password_confirmation'][autocomplete='new-password'][required]"

    patch employee_password_reset_path, params: {
      password: "5678",
      password_confirmation: "5678"
    }

    assert_redirected_to root_path
    assert_equal I18n.t("employee.password_resets.update.success"), flash[:notice]
    employee.reload
    assert_not employee.authenticate("1234")
    assert employee.authenticate("5678")

    follow_redirect!
    assert_response :success
    assert_select ".employee-page-flash.flash-notice > span", text: I18n.t("employee.password_resets.update.success")
  end

  test "password reset requires a valid dni before sending" do
    post employee_password_reset_path, params: {
      national_id: "12345678A",
      delivery_method: "email"
    }

    assert_response :unprocessable_entity
    assert_select ".auth-panel > .flash-alert", text: /DNI\/NIE invàlid/
    assert_select ".auth-panel > .flash-alert + form"
    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_enqueued_jobs 0, only: EmployeeLoginCodeDeliveryJob
  end

  test "password reset does not reveal missing employees or delivery addresses" do
    employee = create_employee(phone: "+34 600 111 222", password: "1234")

    post employee_password_reset_path, params: {
      national_id: employee.national_id,
      delivery_method: "email"
    }

    assert_redirected_to employee_password_reset_code_path
    assert_enqueued_jobs 0, only: EmployeeLoginCodeDeliveryJob
    follow_redirect!
    assert_select ".auth-code-help span", text: I18n.t("employee.password_resets.code.sent_if_found_intro")
    assert_select ".auth-code-help span", text: I18n.t("employee.password_resets.code.sent_if_found.email")

    post verify_employee_password_reset_code_path, params: { code: "111119" }

    assert_response :unprocessable_entity
    assert_select ".auth-panel > .flash-alert > span", text: I18n.t("employee.password_resets.verify_code.invalid")

    post employee_password_reset_path, params: {
      national_id: valid_dni(12_345_680),
      delivery_method: "email"
    }

    assert_redirected_to employee_password_reset_code_path
    assert_enqueued_jobs 0, only: EmployeeLoginCodeDeliveryJob
  end

  test "password reset logs when employee code cooldown skips delivery" do
    employee = create_employee(phone: "+34 600 111 222", password: "1234")
    employee.generate_login_code!(delivery_method: "sms")
    log_output = StringIO.new
    logger = ActiveSupport::Logger.new(log_output)
    original_logger = Rails.logger

    Rails.logger = logger
    begin
      assert_enqueued_jobs 0, only: EmployeeLoginCodeDeliveryJob do
        post employee_password_reset_path, params: {
          authenticity_token: "test-token",
          national_id: employee.national_id,
          delivery_method: "sms",
          commit: "Enviar codi"
        }
      end
    ensure
      Rails.logger = original_logger
    end

    assert_redirected_to employee_password_reset_code_path
    assert_includes log_output.string, "Login code delivery skipped"
    assert_includes log_output.string, "context=employee_password_reset_code_delivery"
    assert_includes log_output.string, "employee_id=#{employee.id}"
    assert_includes log_output.string, "delivery_method=sms"
    assert_includes log_output.string, "reason=cooldown"
    assert_not_includes log_output.string, "Unpermitted parameters"
  end

  test "password reset suppresses form metadata warnings but keeps unexpected parameter warnings" do
    original_action = ActionController::Parameters.action_on_unpermitted_parameters

    ActionController::Parameters.action_on_unpermitted_parameters = :raise
    begin
      post employee_password_reset_path, params: {
        authenticity_token: "test-token",
        national_id: "12345678A",
        delivery_method: "email",
        commit: "Enviar codi"
      }

      error = assert_raises(ActionController::UnpermittedParameters) do
        post employee_password_reset_path, params: {
          authenticity_token: "test-token",
          national_id: "12345678A",
          delivery_method: "email",
          unexpected: "value",
          commit: "Enviar codi"
        }
      end
    ensure
      ActionController::Parameters.action_on_unpermitted_parameters = original_action
    end

    assert_response :unprocessable_entity
    assert_equal [ "unexpected" ], error.params.map(&:to_s)
  end

  test "password setup requires matching passwords after a verified code" do
    employee = create_employee(email: "ada@example.test", password: "1234")

    with_secure_random_number(42) do
      post employee_password_reset_path, params: {
        national_id: employee.national_id,
        delivery_method: "email"
      }
    end
    post verify_employee_password_reset_code_path, params: { code: "000422" }

    patch employee_password_reset_path, params: {
      password: "5678",
      password_confirmation: "8765"
    }

    assert_response :unprocessable_entity
    assert_select ".auth-panel > .error-summary.error-summary-single"
    assert_select ".error-summary-content", text: I18n.t("employee.password_resets.update.password_confirmation_invalid")
    assert employee.reload.authenticate("1234")
  end

  test "password setup skip does not apply to password resets" do
    employee = create_employee(email: "ada@example.test", password: "1234")

    with_secure_random_number(42) do
      post employee_password_reset_path, params: {
        national_id: employee.national_id,
        delivery_method: "email"
      }
    end
    post verify_employee_password_reset_code_path, params: { code: "000422" }

    post skip_employee_password_setup_path

    assert_redirected_to edit_employee_password_reset_path
    assert employee.reload.authenticate("1234")

    get root_path

    assert_redirected_to login_path
  end

  test "password setup redirects without a verified code" do
    get edit_employee_password_reset_path

    assert_redirected_to login_path
    assert_equal I18n.t("employee.password_resets.flash.password_setup_required"), flash[:alert]
  end
end
