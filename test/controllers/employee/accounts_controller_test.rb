require "test_helper"

class Employee::AccountsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "shows persisted account details" do
    employee = create_employee(password: "1234", email: "ada@example.test", phone: "+34 600 111 222")
    employee.tags.create!(name: "office", active: true, color: "#2563eb")
    log_in_employee(employee)

    get account_path

    assert_response :success
    assert_match "ada@example.test", response.body
    assert_match "+34 600 111 222", response.body
    assert_select "input#employee_name[readonly][value='Ada Soler']"
    assert_select "input#employee_national_id[readonly][value='#{employee.national_id}']"
    assert_no_match "office", response.body
    assert_select ".account-layout"
    assert_select ".account-layout .panel", 0
    assert_select ".account-layout h2", 0
    assert_select "form.account-contact-form[action='#{account_contact_path}']"
    assert_select ".account-actions-row"
    assert_select "details.account-password-panel > summary.account-password-summary", text: "Canviar contrasenya"
    assert_select "details.account-password-panel > summary .account-summary-icon-down"
    assert_select "details.account-password-panel > summary .account-summary-icon-up"
    assert_select "details.account-password-panel form.account-password-form[action='#{account_password_path}']"
    assert_select "details.account-password-panel form.account-password-form input[name='current_password']", 0
    assert_select ".account-save-button.account-primary-button[form='account_contact_form'][data-submitting-label='Desant...']", text: "Desar canvis"
    assert_select ".account-password-form .account-primary-button[data-submitting-label='Canviant...']", text: "Canviar contrasenya"
    assert_select "hr.account-divider + section.account-hr-contact#human_resources_contact"
    assert_select ".account-hr-contact h2", text: "Contactar amb Recursos Humans"
    assert_select "form.account-hr-contact-form[action='#{account_human_resources_contact_path}'][autocomplete='off']"
    assert_select ".account-hr-contact-form input[name='subject'][placeholder='Assumpte'][autocomplete='off']"
    assert_select ".account-hr-contact-form textarea[name='message'][placeholder='Missatge'][autocomplete='off']"
    assert_select ".account-hr-contact-form button[type='submit'][data-submitting-label='Enviant...']", text: "Envia"
  end

  test "updates contact details" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    patch account_contact_path, params: {
      email: "new@example.test",
      phone: "+34 611 222 333",
      current_password: "bad",
      password: "5678",
      password_confirmation: "5678"
    }

    assert_redirected_to account_path
    employee.reload
    assert_equal "new@example.test", employee.email
    assert_equal "+34 611 222 333", employee.phone
    assert employee.authenticate("1234")
    assert_not employee.authenticate("5678")

    follow_redirect!
    assert_select ".page-intro + .employee-page-flash.dismissible-flash"
    assert_select ".employee-page-flash.flash-notice .flash-icon"
    assert_select ".employee-page-flash > span", text: I18n.t("employee.flash.account_updated")
    assert_select ".employee-page-flash .flash-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
  end

  test "changes an existing password without current password" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    patch account_password_path, params: {
      email: "new@example.test",
      phone: "+34 611 222 333",
      password: "5678",
      password_confirmation: "5678"
    }

    assert_redirected_to account_path
    employee.reload
    assert_not_equal "new@example.test", employee.email
    assert_not_equal "+34 611 222 333", employee.phone
    assert_not employee.authenticate("1234")
    assert employee.authenticate("5678")
  end

  test "requires a new password in the password form" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    patch account_password_path, params: {}

    assert_response :unprocessable_entity
    assert_select "details.account-password-panel[open]"
    assert_select ".account-section > .error-summary", 0
    assert_select "details.account-password-panel[open] > .error-summary.error-summary-single"
    assert_select "details.account-password-panel[open] > .error-summary .error-summary-content", text: I18n.t("employee.accounts.update_password.password_blank")
    assert_select "details.account-password-panel[open] > .error-summary .error-summary-icon"
    assert_select "details.account-password-panel[open] > .error-summary .error-summary-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
    assert_select "details.account-password-panel[open] > .error-summary strong", 0
    assert_select "details.account-password-panel[open] > .error-summary ul", 0
    assert employee.reload.authenticate("1234")
  end

  test "ignores submitted current password when changing password" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    patch account_password_path, params: {
      current_password: "bad",
      password: "5678",
      password_confirmation: "5678"
    }

    assert_redirected_to account_path
    assert employee.reload.authenticate("5678")
  end

  test "sends human resources contact email and clears the form" do
    employee = create_employee(password: "1234", email: "ada@example.test", phone: "+34 600 111 222")
    log_in_employee(employee)

    assert_enqueued_emails 1 do
      post account_human_resources_contact_path, params: {
        subject: "Vacances pendents",
        message: "Necessito revisar els dies disponibles."
      }
    end

    assert_redirected_to account_path(anchor: "human_resources_contact")
    assert_equal 0, ActionMailer::Base.deliveries.size
    deliver_enqueued_emails

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ Rails.configuration.x.human_resources_email ], mail.to
    assert_equal [ "ada@example.test" ], mail.reply_to
    assert_equal "FitxaCAE RRHH: Vacances pendents", mail.subject
    assert_match "Ada Soler", mail.text_part.body.decoded
    assert_match employee.national_id, mail.text_part.body.decoded
    assert_match "Necessito revisar els dies disponibles.", mail.text_part.body.decoded

    follow_redirect!
    assert_select ".page-intro + .employee-page-flash", 0
    assert_select ".account-hr-contact h2 + .account-hr-flash.dismissible-flash"
    assert_select ".account-hr-flash.flash-hr_contact_notice .flash-icon"
    assert_select ".account-hr-flash > span", text: I18n.t("employee.accounts.contact_human_resources.sent")
    assert_select ".account-hr-flash .flash-close[aria-label='Tancar avís'][data-action='dismissible#dismiss']", text: "×"
    assert_no_match "Vacances pendents", response.body
    assert_no_match "Necessito revisar els dies disponibles.", response.body
  end

  test "keeps human resources contact form values when message is blank" do
    employee = create_employee(password: "1234")
    log_in_employee(employee)

    assert_no_enqueued_emails do
      post account_human_resources_contact_path, params: {
        subject: "Nòmina",
        message: ""
      }
    end

    assert_response :unprocessable_entity
    assert_select ".account-hr-contact h2 + .account-hr-flash.flash-alert"
    assert_select ".account-hr-flash.flash-alert .flash-icon"
    assert_select ".account-hr-flash > span", text: I18n.t("employee.accounts.contact_human_resources.blank")
    assert_select ".account-hr-contact-form input[name='subject'][value='Nòmina']"
  end
end
