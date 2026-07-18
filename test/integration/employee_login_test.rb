require "test_helper"

class EmployeeLoginTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    Employee::SessionsController::CODE_REQUEST_RATE_LIMIT_STORE.clear
  end

  test "redirects employee pages to login when signed out" do
    get login_path
    assert_response :success
    assert_select "title", text: "Iniciar sessió | FitxaCAE"
    assert_select ".employee-auth-card .brand-mark"
    assert_select ".employee-auth-card .auth-panel", 1
    assert_select ".auth-methods", 0
    assert_select "body[data-controller='pwa-session']"
    assert_select ".employee-install-prompt .employee-install-button", text: /Instal·la FitxaCAE/
    assert_select ".employee-install-prompt .employee-install-button .icon"
    assert_select ".auth-tab-list", text: /Contrasenya/
    assert_select ".auth-tab-list", text: /Rebre codi/
    assert_select "#employee_login_password_tab[checked]"
    assert_select "#employee_delivery_method_email[checked]"
    assert_select "#employee_delivery_method_sms[checked]", 0
    assert_equal [ "Correu", "SMS" ], css_select(".delivery-method-options label").map { |label| label.text.squish }
    assert_select ".employee-auth-card .auth-panel .flash", 0
    assert_select ".employee-auth-shell > .flash", 0
    assert_select ".employee-auth-footer a[href='https://github.com/royalmo/fitxa-cae.git'][target='_blank'][rel='noopener']", text: "FitxaCAE"
    assert_select ".employee-auth-footer a[href='https://ericroy.net']", 0
    assert_select ".employee-auth-footer a[href='https://cae.cat/avisos-legals/'][target='_blank'][rel='noopener']", text: "Avís legal"
    assert_select ".employee-auth-footer a.auth-footer-access[href='/admin']", text: "Accés admin"
    assert_select ".employee-auth-footer a[href='/admin'][target]", 0
    assert_no_match "Desenvolupat per", response.body
    assert_equal "FitxaCAE v#{Rails.configuration.x.app_version} · Avís legal · Accés admin",
      css_select(".employee-auth-footer").first.text.squish

    get root_path

    assert_redirected_to login_path
    assert_nil flash[:alert]

    get clockings_path

    assert_redirected_to login_path
    assert_equal I18n.t("employee.sessions.flash.require_login"), flash[:alert]
  end

  test "password login signs in an active employee" do
    employee = create_employee(password: "1234")

    post login_path, params: {
      national_id: employee.national_id.downcase,
      password: "1234"
    }

    assert_redirected_to root_path
    assert_nil flash[:notice]
    follow_redirect!
    assert_response :success
  end

  test "head request to employee page stores return path" do
    employee = create_employee(password: "1234")

    head clockings_path
    assert_redirected_to login_path

    post login_path, params: {
      national_id: employee.national_id,
      password: "1234"
    }

    assert_redirected_to clockings_path
  end

  test "password login rejects bad credentials and inactive employees" do
    employee = create_employee(password: "1234")
    inactive = create_employee(national_id: valid_dni(12_345_679), password: "1234", active: false)

    post login_path, params: { national_id: employee.national_id, password: "bad" }
    assert_response :unprocessable_entity
    assert_select "#employee_login_password_tab[checked]"
    assert_select ".auth-tab-panel-password > .flash-alert + form"
    assert_select ".auth-tab-panel-password .flash-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
    assert_select ".auth-tab-panel-code .flash", 0
    assert_select ".employee-auth-shell > .flash", 0

    post login_path, params: { national_id: inactive.national_id, password: "1234" }
    assert_response :unprocessable_entity
  end

  test "remembered browser sessions last thirty days" do
    employee = create_employee(password: "1234")

    travel_to Time.zone.local(2026, 7, 1, 9, 0) do
      post login_path, params: {
        national_id: employee.national_id,
        password: "1234",
        remember_me: "1",
        installed_pwa: "0"
      }
    end

    assert_match(/expires=.*31 Jul 2026/i, response.headers["Set-Cookie"])
  end

  test "remembered installed pwa sessions last one year" do
    employee = create_employee(password: "1234")

    travel_to Time.zone.local(2026, 7, 1, 9, 0) do
      post login_path, params: {
        national_id: employee.national_id,
        password: "1234",
        remember_me: "1",
        installed_pwa: "1"
      }
    end

    assert_match(/expires=.*1 Jul 2027/i, response.headers["Set-Cookie"])
  end

  test "email code login sends and verifies a code" do
    employee = create_employee(email: "ada@example.test")

    with_secure_random_number(42) do
      post request_login_code_path, params: {
        national_id: employee.national_id,
        delivery_method: "email"
      }
    end

    assert_redirected_to login_code_path
    assert_nil flash[:notice]
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_match "000422", ActionMailer::Base.deliveries.last.text_part.body.to_s
    follow_redirect!
    assert_select "title", text: "Codi d'accés | FitxaCAE"
    assert_no_match "&amp;#", response.body
    assert_select ".auth-code-help span", text: I18n.t("employee.sessions.code.sent_if_found_intro")
    assert_select ".auth-code-help span", text: I18n.t("employee.sessions.code.sent_if_found.email")
    assert_select ".auth-panel-actions .auth-back-link[href='#{login_path}']", text: /Enrere/
    assert_select ".auth-secondary-action", 0
    assert_select ".employee-auth-card .auth-panel > .flash", 0
    assert_select ".employee-auth-card .auth-panel > form"
    assert_select ".code-input-group legend.sr-only", text: "Codi"
    assert_select ".code-inputs .code-digit-input", 6
    assert_select ".code-inputs input[name='code_digits[]']", 6
    assert_select ".code-inputs input[required]", 6
    assert_select ".code-inputs input[autocomplete='off']", 6
    assert_select ".code-input-group input[type='hidden'][name='code']", 1
    assert_select "form.auth-form[autocomplete='off'][data-controller='code-input'][data-code-input-submitting-label-value='Entrant...']"
    assert_select "form.auth-form input[type='submit'][data-code-input-target='submit']"
    assert_select ".field label", 0
    assert_select ".employee-auth-shell > .flash", 0

    post verify_login_code_path, params: { code: "000422" }

    assert_redirected_to root_path
    assert_nil flash[:notice]
    assert_nil employee.reload.settings["login_code"]
  end

  test "sms code login stores hashed code and verifies it" do
    employee = create_employee(phone: "+34 600 111 222")

    with_secure_random_number(12_345) do
      post request_login_code_path, params: {
        national_id: employee.national_id,
        delivery_method: "sms"
      }
    end

    assert_redirected_to login_code_path
    assert_equal "sms", employee.reload.settings.dig("login_code", "delivery_method")
    assert_not_includes employee.settings.to_s, "123456"

    post verify_login_code_path, params: { code: "123456" }

    assert_redirected_to root_path
  end

  test "code login accepts six individual digit inputs" do
    employee = create_employee(email: "ada@example.test")

    with_secure_random_number(65_432) do
      post request_login_code_path, params: {
        national_id: employee.national_id,
        delivery_method: "email"
      }
    end

    post verify_login_code_path, params: { code_digits: %w[6 5 4 3 2 8] }

    assert_redirected_to root_path
  end

  test "sms code login handles smsarena delivery errors" do
    employee = create_employee(phone: "+34 600 111 222")
    singleton = class << SmsArena
      self
    end
    original_method = SmsArena.method(:deliver_login_code)

    singleton.define_method(:deliver_login_code) do |**_kwargs|
      raise SmsArena::DeliveryError, Struct.new(:code).new(500)
    end

    with_error_notifications do |notifications|
      post request_login_code_path, params: {
        national_id: employee.national_id,
        delivery_method: "sms"
      }

      assert_redirected_to login_code_path
      assert_nil employee.reload.settings["login_code"]
      assert_equal 1, notifications.size
      assert_equal "sms", notifications.first[:data][:delivery_method]
      assert_equal employee.id, notifications.first[:data][:employee_id]
    end
  ensure
    singleton.define_method(:deliver_login_code, original_method) if original_method
  end

  test "code login rejects invalid dni before sending" do
    post request_login_code_path, params: {
      national_id: "12345678A",
      delivery_method: "email"
    }

    assert_response :unprocessable_entity
    assert_select "#employee_login_code_tab[checked]"
    assert_select ".auth-tab-panel-code > .flash-alert", text: /DNI\/NIE invàlid/
    assert_select ".auth-tab-panel-code > .flash-alert + form"
    assert_select ".auth-tab-panel-code .flash-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
    assert_select ".auth-tab-panel-password .flash", 0
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "code login does not reveal missing employees or delivery addresses" do
    employee = create_employee(phone: "+34 600 111 222")

    post request_login_code_path, params: {
      national_id: employee.national_id,
      delivery_method: "email"
    }
    assert_redirected_to login_code_path
    assert_equal 0, ActionMailer::Base.deliveries.size
    follow_redirect!
    assert_select ".auth-code-help span", text: I18n.t("employee.sessions.code.sent_if_found_intro")
    assert_select ".auth-code-help span", text: I18n.t("employee.sessions.code.sent_if_found.email")

    post verify_login_code_path, params: { code: "111119" }
    assert_response :unprocessable_entity

    post request_login_code_path, params: {
      national_id: valid_dni(12_345_680),
      delivery_method: "email"
    }
    assert_redirected_to login_code_path
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "code login alerts and notifies when selected channel is not configured" do
    employee = create_employee(email: "ada@example.test")

    with_login_code_delivery_config(email: false) do
      with_error_notifications do |notifications|
        post request_login_code_path, params: {
          national_id: employee.national_id,
          delivery_method: "email"
        }

        assert_response :bad_gateway
        assert_select "#employee_login_code_tab[checked]"
        assert_select ".auth-tab-panel-code > .flash-alert", text: /No s'ha pogut enviar el correu/
        assert_select ".auth-tab-panel-code > .flash-alert + form"
        assert_select ".auth-tab-panel-code .flash-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
        assert_select ".auth-tab-panel-password .flash", 0
        assert_equal 1, notifications.size
        assert_instance_of LoginCodeDeliveryConfig::ConfigurationError, notifications.first[:error]
        assert_equal "email", notifications.first[:data][:delivery_method]
      end
    end
  end

  test "code login alerts and notifies when sms is not configured" do
    employee = create_employee(phone: "+34 600 111 222")

    with_login_code_delivery_config(sms: false) do
      with_error_notifications do |notifications|
        post request_login_code_path, params: {
          national_id: employee.national_id,
          delivery_method: "sms"
        }

        assert_response :bad_gateway
        assert_select "#employee_login_code_tab[checked]"
        assert_select ".auth-tab-panel-code > .flash-alert", text: /No s'ha pogut enviar l'SMS/
        assert_select ".auth-tab-panel-code > .flash-alert + form"
        assert_equal 1, notifications.size
        assert_instance_of LoginCodeDeliveryConfig::ConfigurationError, notifications.first[:error]
        assert_equal "sms", notifications.first[:data][:delivery_method]
      end
    end
  end

  test "code login rejects expired codes" do
    employee = create_employee(phone: "+34 600 111 222")

    with_secure_random_number(55_555) do
      post request_login_code_path, params: {
        national_id: employee.national_id,
        delivery_method: "sms"
      }
    end

    travel Employee::LOGIN_CODE_TTL + 1.minute
    post verify_login_code_path, params: { code: "555550" }
    assert_response :unprocessable_entity
  end

  test "code login rate limits repeated requests for the same employee" do
    employee = create_employee(email: "ada@example.test")

    post request_login_code_path, params: {
      national_id: employee.national_id,
      delivery_method: "email"
    }
    assert_redirected_to login_code_path

    post request_login_code_path, params: {
      national_id: employee.national_id,
      delivery_method: "email"
    }
    assert_redirected_to login_code_path
    assert_equal 1, ActionMailer::Base.deliveries.size

    travel Employee::LOGIN_CODE_COOLDOWN + 1.second

    (Employee::LOGIN_CODE_LIMIT - 1).times do
      post request_login_code_path, params: {
        national_id: employee.national_id,
        delivery_method: "email"
      }
      assert_redirected_to login_code_path
      travel Employee::LOGIN_CODE_COOLDOWN + 1.second
    end

    post request_login_code_path, params: {
      national_id: employee.national_id,
      delivery_method: "email"
    }
    assert_redirected_to login_code_path
    assert_equal Employee::LOGIN_CODE_LIMIT, ActionMailer::Base.deliveries.size
  end

  test "code login rate limits repeated requests by ip" do
    employees = 11.times.map do |index|
      create_employee(national_id: valid_dni(20_000_000 + index), email: "employee#{index}@example.test")
    end

    employees.first(10).each do |employee|
      post request_login_code_path, params: {
        national_id: employee.national_id,
        delivery_method: "email"
      }
      assert_redirected_to login_code_path
    end

    post request_login_code_path, params: {
      national_id: employees.last.national_id,
      delivery_method: "email"
    }

    assert_redirected_to login_path(delivery_method: "email")
    assert_equal I18n.t("employee.sessions.request_code.rate_limited"), flash[:alert]
    follow_redirect!
    assert_select "#employee_login_code_tab[checked]"
    assert_select ".auth-tab-panel-code > .flash-alert + form"
    assert_select ".auth-tab-panel-password .flash", 0
  end

  private

  def with_error_notifications
    singleton = class << ErrorNotifier
      self
    end
    original_method = ErrorNotifier.method(:notify)
    notifications = []

    singleton.define_method(:notify) do |error, data: {}|
      notifications << { error: error, data: data }
    end
    yield notifications
  ensure
    singleton.define_method(:notify, original_method) if original_method
  end

  def with_login_code_delivery_config(email: true, sms: true)
    singleton = class << LoginCodeDeliveryConfig
      self
    end
    original_method = LoginCodeDeliveryConfig.method(:configured?)

    singleton.define_method(:configured?) do |delivery_method|
      case delivery_method.to_s
      when "email"
        email
      when "sms"
        sms
      else
        false
      end
    end
    yield
  ensure
    singleton.define_method(:configured?, original_method) if original_method
  end
end
