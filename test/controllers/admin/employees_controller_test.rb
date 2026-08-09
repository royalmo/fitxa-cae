require "test_helper"

class Admin::EmployeesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
    log_in_manager
  end

  test "lists employees from the database" do
    tag = Tag.create!(name: "office", active: true, color: "#2563eb")
    employee = create_employee(
      first_name: "Nora",
      last_name: "Vidal",
      email: "nora@example.test",
      phone: "+34 600 111 222"
    )
    inactive_employee = create_employee(
      first_name: "Ona",
      last_name: "Costa",
      national_id: valid_dni(41_000_006),
      active: false
    )
    untagged_employee = create_employee(
      first_name: "Lia",
      last_name: "Bosc",
      national_id: valid_dni(41_000_007)
    )
    employee.tags << tag
    inactive_employee.tags << tag
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 16, 0), metadata: "employee_portal")

    get admin_employees_path

    assert_response :success
    assert_match "Nora Vidal", response.body
    assert_match "nora@example.test", response.body
    assert_match "office", response.body
    assert_select "[data-controller='list-loading']"
    assert_select "h2", text: "Filtres", count: 0
    assert_no_match "Sense contacte", response.body
    assert_no_match "Sense etiquetes", response.body
    assert_no_match "Sense fitxatges", response.body
    assert_select ".admin-result-count[data-list-loading-target='results']",
      text: "Mostrant 1-#{[ Employee.count, 20 ].min} de #{Employee.count}"
    assert_select ".text-center .admin-result-count",
      text: "Mostrant 1-#{[ Employee.count, 20 ].min} de #{Employee.count}"
    assert_select "button#adminEmployeeBulkActionsMenu.dropdown-toggle[data-bs-toggle='dropdown'][aria-expanded='false']", text: "Accions massives" do
      assert_select "svg.icon"
    end
    assert_select "ul.dropdown-menu[aria-labelledby='adminEmployeeBulkActionsMenu']" do
      assert_select "a.dropdown-item[href='#{new_admin_import_path}']", text: "Importar persones" do
        assert_select "svg.icon"
      end
      assert_select "a.dropdown-item[href='#{bulk_activation_admin_employees_path}']", text: "Activar i desactivar" do
        assert_select "svg.icon"
      end
      assert_select "a.dropdown-item[href='#{bulk_tags_admin_employees_path}']", text: "Afegir etiquetes" do
        assert_select "svg.icon"
      end
    end
    assert_select "a.btn[href='#{new_admin_employee_path}']", text: "Nova persona"
    assert_select "form.admin-employees-filter-form[action='#{admin_employees_path}'][method='get']" do
      assert_select "input[type='search'][name='q'][placeholder='Nom, DNI/NIE o correu']"
      assert_select "button[type='submit'][aria-label='Cercar'] svg.icon"
      assert_select ".admin-tag-search[data-tag-search-url-value='#{admin_tag_search_path}']" do
        assert_select "input[type='hidden'][name='tag_id'][value='']"
        assert_select "input[name='tag_query'][placeholder='Cerca una etiqueta']"
        assert_select "button[type='button'][aria-label='Totes les etiquetes'][data-action='tag-search#clear'] svg.icon"
      end
      assert_select "select[name='tag_id']", count: 0
      assert_select "select[name='status']", count: 0
      assert_select "input[type='radio'][name='status'][value=''][checked='checked'][autocomplete='off'] + label", text: "Totes"
      assert_select "input[type='radio'][name='status'][value='active'][autocomplete='off'] + label", text: "Actives"
      assert_select "input[type='radio'][name='status'][value='disabled'][autocomplete='off'] + label", text: "Inactives"
      assert_select "button", text: "Filtrar", count: 0
    end
    assert_select "thead th", text: "Estat", count: 0
    assert_select "thead th", text: "Hores del mes", count: 0
    assert_select "thead th:nth-child(1)", text: "Nom"
    assert_select "thead th:nth-child(5)", text: "Accions"
    assert_select "tbody tr.admin-employee-row.is-inactive", count: 1
    assert_select "tbody .admin-employee-name strong[title='Nora Vidal']", text: "Nora Vidal"
    assert_select "tbody .admin-employee-name svg.admin-employee-status-icon.is-active", count: 0
    assert_select "tbody tr.admin-employee-row.is-inactive .admin-employee-name svg.admin-employee-status-icon.is-inactive[aria-label='Inactiu'] + strong[title='Ona Costa']",
      text: "Ona Costa"
    assert_select ".admin-employee-contact[title='+34 600 111 222 · nora@example.test']", text: "+34 600 111 222 · nora@example.test"
    assert_select ".admin-employee-tags .admin-tag-label[style*='#2563eb']" do
      assert_select "svg.admin-tag-label-icon + span", text: "office"
    end
    assert_select "tbody tr.admin-employee-row .admin-employee-contact", count: 1
    assert_select "tbody tr.admin-employee-row .admin-employee-tags-empty", text: "-", count: 1
    assert_select ".admin-employee-last-clocking.is-exit[title='Sortida 02/07/2026 16:00']",
      text: /02\/07\/2026\s+16:00/ do
      assert_select "svg.admin-employee-last-clocking-icon[aria-label='Sortida'][title='Sortida']"
    end
    assert_select "tbody tr.admin-employee-row .admin-employee-last-clocking-empty", text: "-", count: 2
    assert_select "tbody tr.admin-employee-row.is-inactive .admin-employee-tags .admin-tag-label[style*='#2563eb']" do
      assert_select "svg.admin-tag-label-icon + span", text: "office"
    end
    activation_modal_id = "employee_activation_modal_#{employee.id}"
    assert_select "button.admin-row-action[data-bs-toggle='modal'][data-bs-target='##{activation_modal_id}'][aria-label='Desactivar persona Nora Vidal'] svg.icon"
    assert_select "##{activation_modal_id}.modal.fade[aria-labelledby='#{activation_modal_id}_label']" do
      assert_select "h2##{activation_modal_id}_label", text: "Desactivar persona"
      assert_select ".modal-body", text: /Vols desactivar Nora Vidal\?/
      assert_select ".modal-body", text: /No podrà iniciar sessió ni fitxar mentre estigui inactiva/
      assert_select "form[action='#{activation_admin_employee_path(employee)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "input[name='employee[active]'][value='false']"
        assert_select "button[type='submit']", text: "Desactivar"
      end
    end
    activation_modal_id = "employee_activation_modal_#{inactive_employee.id}"
    assert_select "button.admin-row-action[data-bs-toggle='modal'][data-bs-target='##{activation_modal_id}'][aria-label='Activar persona Ona Costa'] svg.icon"
    assert_select "##{activation_modal_id}.modal.fade[aria-labelledby='#{activation_modal_id}_label']" do
      assert_select "h2##{activation_modal_id}_label", text: "Activar persona"
      assert_select ".modal-body", text: /Vols activar Ona Costa\?/
      assert_select ".modal-body", text: /Podrà iniciar sessió i fitxar de nou/
      assert_select "form[action='#{activation_admin_employee_path(inactive_employee)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "input[name='employee[active]'][value='true']"
        assert_select "button[type='submit']", text: "Activar"
      end
    end
    assert_select "tbody td", text: "Actiu", count: 0
    assert_select "tbody td", text: "Inactiu", count: 0
    today = Time.zone.today
    calendar_path = admin_calendars_path(employee_id: employee.id, employee_query: "Nora Vidal", year: today.year)
    swipes_path = admin_swipes_path(employee_id: employee.id, employee_query: "Nora Vidal", month: today.month, year: today.year)
    assert_select "a.btn.admin-row-action[href='#{calendar_path}'][aria-label='Veure calendari de Nora Vidal'] svg.icon"
    assert_select "a.btn.admin-row-action[href='#{swipes_path}'][aria-label='Veure fitxatges de Nora Vidal'] svg.icon"
    action_links = css_select("a[href='#{edit_admin_employee_path(employee)}']").first.parent.css("a").map { |link| link["href"] }
    assert_equal [ calendar_path, swipes_path, edit_admin_employee_path(employee) ], action_links
    assert_select "a.btn.admin-row-action[href='#{edit_admin_employee_path(employee)}'][aria-label='Editar'] svg.icon"
    assert_select "a.btn.admin-row-action[href='#{edit_admin_employee_path(inactive_employee)}'][aria-label='Editar'] svg.icon"
    assert_select "a.btn.admin-row-action[href='#{edit_admin_employee_path(untagged_employee)}'][aria-label='Editar'] svg.icon"
    assert_select ".badge.text-bg-success", count: 0
  end

  test "filters employees by search status and tag" do
    tag = Tag.create!(name: "warehouse", active: true, color: "#16a34a")
    visible = create_employee(first_name: "Marc", last_name: "Riera", national_id: valid_dni(41_000_001), active: true)
    hidden = create_employee(first_name: "Ada", last_name: "Riera", national_id: valid_dni(41_000_002), active: false)
    visible.tags << tag

    get admin_employees_path, params: { q: "marc", status: "active", tag_id: tag.id }

    assert_response :success
    assert_match "Marc Riera", response.body
    assert_no_match "Ada Riera", response.body
    assert_no_match hidden.national_id, response.body
    assert_select "input[type='search'][name='q'][value='marc']"
    assert_select "input[name='tag_id'][value='#{tag.id}']"
    assert_select "input[name='tag_query'][value='warehouse']"
    assert_select ".admin-tag-search-field.has-selected-tag" do
      assert_select ".admin-tag-search-selection.admin-tag-label[style*='#16a34a']" do
        assert_select "svg.admin-tag-label-icon + span", text: "warehouse"
      end
    end
    assert_select "input[type='radio'][name='status'][value='active'][checked='checked'] + label", text: "Actives"
  end

  test "paginates employee list" do
    25.times do |index|
      create_employee(
        first_name: "Persona",
        last_name: format("P%02d", index),
        national_id: valid_dni(42_000_000 + index)
      )
    end

    get admin_employees_path

    expected_count = Employee.count
    assert_response :success
    assert_select ".admin-result-count", text: "Mostrant 1-20 de #{expected_count}"
    assert_select "a.admin-page-link[href='#{admin_employees_path(page: 2)}'][data-action='click->list-loading#navigate']", text: /Següent/
    assert_match "Persona P00", response.body
    assert_no_match "Persona P24", response.body

    get admin_employees_path, params: { page: 2 }

    assert_response :success
    assert_select ".admin-result-count", text: "Mostrant 21-#{expected_count} de #{expected_count}"
    assert_match "Persona P24", response.body
  end

  test "renders new employee form controls" do
    Tag.create!(name: "office", active: true, color: "#2563eb")
    new_tag_path = admin_tags_path(open: "new")

    get new_admin_employee_path

    assert_response :success
    assert_select "a.admin-page-close-action[href='#{admin_employees_path}'][aria-label='Tornar a persones'] svg.icon"
    assert_select "button[type='submit']", text: "Crear"
    assert_select "button[type='submit']", text: "Desar", count: 0
    assert_select "input[type='password'][name='employee[password]']", count: 0
    assert_select "input[type='text'][name='employee[national_id]']:not([disabled])"
    assert_select "select[name='employee[active]']", count: 0
    assert_select "fieldset.admin-status-radio-fieldset" do
      assert_select "legend.form-label", text: "Estat"
      assert_select ".admin-status-radio-group.btn-group.w-100" do
        assert_select "input[type='radio'][name='employee[active]'][value='true'][checked='checked'][disabled] + label.admin-status-radio-option.is-active" do
          assert_select "svg.admin-status-radio-icon"
          assert_select "span", text: "Activa"
        end
        assert_select "input[type='radio'][name='employee[active]'][value='false'][disabled] + label.admin-status-radio-option.is-inactive" do
          assert_select "svg.admin-status-radio-icon"
          assert_select "span", text: "Inactiva"
        end
      end
    end
    assert_select "input[type='checkbox'][name='employee[tag_ids][]']", count: 0
    assert_select ".admin-tag-multi-search[data-controller='tag-multi-search'][data-tag-multi-search-url-value='#{admin_tag_search_path}']" do
      assert_select "input.admin-tag-multi-search-input[name='employee_tag_query'][placeholder='Cerca una etiqueta'][role='combobox']"
      assert_select "a.admin-tag-multi-search-create[href='#{new_tag_path}'][target='_blank'][rel='noopener'][aria-label='Nova etiqueta'] svg.icon"
      assert_select "#admin-employee-tag-results.admin-tag-multi-search-results[role='listbox']"
      assert_select ".admin-tag-multi-search-selections > .admin-tag-multi-search-selection", count: 0
      assert_select "template[data-tag-multi-search-target='selectionTemplate']"
    end
  end

  test "renders edit employee form controls" do
    active_tag = Tag.create!(name: "office", active: true, color: "#2563eb")
    inactive_tag = Tag.create!(name: "archived", active: false, color: "#16a34a")
    employee = create_employee(first_name: "Iria", last_name: "Mas", national_id: valid_dni(41_000_009), active: false)
    employee.tags << active_tag
    employee.tags << inactive_tag

    get edit_admin_employee_path(employee)

    assert_response :success
    assert_select "a.admin-page-close-action[href='#{admin_employees_path}'][aria-label='Tornar a persones'] svg.icon"
    assert_select "button[type='submit']", text: "Desar"
    assert_select "button[type='submit']", text: "Crear", count: 0
    assert_select "input[type='password'][name='employee[password]']", count: 0
    assert_select "input[type='text'][name='employee[national_id]'][value='#{employee.national_id}']:not([disabled])"
    assert_select "select[name='employee[active]']", count: 0
    assert_select "fieldset.admin-status-radio-fieldset" do
      assert_select "legend.form-label", text: "Estat"
      assert_select ".admin-status-radio-group.btn-group.w-100" do
        assert_select "input[type='radio'][name='employee[active]'][value='true']:not([disabled]) + label.admin-status-radio-option.is-active" do
          assert_select "svg.admin-status-radio-icon"
          assert_select "span", text: "Activa"
        end
        assert_select "input[type='radio'][name='employee[active]'][value='false'][checked='checked']:not([disabled]) + label.admin-status-radio-option.is-inactive" do
          assert_select "svg.admin-status-radio-icon"
          assert_select "span", text: "Inactiva"
        end
      end
    end
    assert_select "input[type='checkbox'][name='employee[tag_ids][]']", count: 0
    assert_select ".admin-tag-multi-search-selections > .admin-tag-multi-search-selection.admin-tag-label", count: 2
    assert_select ".admin-tag-multi-search-selection[style*='#2563eb']" do
      assert_select "input[type='hidden'][name='employee[tag_ids][]'][value='#{active_tag.id}']"
      assert_select "button.admin-tag-multi-search-remove[aria-label='Eliminar etiqueta office'] svg.icon"
    end
    assert_select ".admin-tag-multi-search-selection[style*='#16a34a']" do
      assert_select "input[type='hidden'][name='employee[tag_ids][]'][value='#{inactive_tag.id}']"
      assert_select "button.admin-tag-multi-search-remove[aria-label='Eliminar etiqueta archived'] svg.icon"
    end
  end

  test "renders employment period summary on edit when employee has history" do
    employee = create_employee(first_name: "Iria", last_name: "Mas", national_id: valid_dni(41_000_014))
    employee.current_employment_period.update!(started_at: Time.zone.local(2026, 8, 1, 8, 0))
    employee.employment_periods.create!(
      started_at: Time.zone.local(2026, 7, 1, 8, 0),
      ended_at: Time.zone.local(2026, 7, 15, 18, 0)
    )

    get edit_admin_employee_path(employee)

    assert_response :success
    assert_select ".admin-employment-periods" do
      assert_select "h2", text: "Períodes d'activació"
      assert_select "li", text: /1\/7\/2026\s+-\s+15\/7\/2026/
      assert_select "li", text: /1\/8\/2026\s+-\s+Actualment/
    end
  end

  test "renders old employee national id field disabled with tooltip" do
    employee = create_employee(first_name: "Iria", last_name: "Mas", national_id: valid_dni(41_000_010))
    employee.update_columns(created_at: 25.hours.ago)
    tooltip = "Crea una nova persona si vols canvia el DNI/NIE."

    get edit_admin_employee_path(employee)

    assert_response :success
    assert_select "span[data-controller='bootstrap-tooltip'][data-bs-toggle='tooltip'][data-bs-placement='top'][title='#{tooltip}'][tabindex='0']" do
      assert_select "input[type='text'][name='employee[national_id]'][value='#{employee.national_id}'][disabled='disabled'][title='#{tooltip}']"
    end
  end

  test "tag search renders multi select results" do
    selected = Tag.create!(name: "office", active: true, color: "#2563eb")
    visible = Tag.create!(name: "offsite", active: true, color: "#16a34a")
    inactive = Tag.create!(name: "offline", active: false, color: "#6b7280")

    get admin_tag_search_path, params: { q: "off", multiple: "true", selected_tag_ids: selected.id.to_s }

    assert_response :success
    assert_no_match inactive.name, response.body
    assert_select "button.admin-tag-search-result[data-action='tag-multi-search#select'][data-tag-multi-search-id-param='#{selected.id}'][disabled]" do
      assert_select ".admin-tag-label", text: "office"
    end
    assert_select "button.admin-tag-search-result[data-action='tag-multi-search#select'][data-tag-multi-search-id-param='#{visible.id}']:not([disabled])" do
      assert_select ".admin-tag-label", text: "offsite"
    end
    assert_select "button[data-action='tag-search#select']", count: 0
  end

  test "creates an active employee with tags" do
    tag = Tag.create!(name: "office", active: true, color: "#2563eb")

    assert_difference "Employee.count", 1 do
      assert_enqueued_emails 1 do
        post admin_employees_path, params: {
          employee: {
            first_name: "Pau",
            last_name: "Costa",
            national_id: valid_dni(41_000_003),
            email: "pau@example.test",
            phone: "+34 600 111 222",
            active: "0",
            tag_ids: [ tag.id ]
          }
        }
      end
    end

    assert_redirected_to admin_employees_path
    employee = Employee.last
    assert_predicate employee, :active?
    assert_predicate employee.current_employment_period, :open?
    assert_equal [ tag ], employee.tags.to_a
    assert_not employee.password_login_enabled?

    deliver_enqueued_emails
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "pau@example.test" ], mail.to
    assert_equal I18n.t("employee_welcome_mailer.welcome.subject"), mail.subject
    assert_equal [ "rrhh@cae.cat" ], mail.reply_to
    assert_match "Pau Costa", mail.text_part.body.decoded
    assert_match "DNI o NIE", mail.text_part.body.decoded
  end

  test "does not send welcome email when created employee has no email" do
    assert_difference "Employee.count", 1 do
      assert_no_enqueued_emails do
        post admin_employees_path, params: {
          employee: {
            first_name: "Pau",
            last_name: "Costa",
            national_id: valid_dni(41_000_013),
            active: "0"
          }
        }
      end
    end

    assert_redirected_to admin_employees_path
  end

  test "renders validation errors when employee data is invalid" do
    post admin_employees_path, params: {
      employee: {
        first_name: "",
        national_id: "bad",
        active: "1"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".error-summary"
    assert_select ".error-summary li", text: "DNI no és vàlid"
    assert_no_match "National no és vàlid", response.body
    assert_select "button[type='submit'][data-submitting-label='Desant...']"
  end

  test "updates an employee and can clear tags" do
    tag = Tag.create!(name: "office", active: true, color: "#2563eb")
    employee = create_employee(first_name: "Iria", last_name: "Mas", national_id: valid_dni(41_000_004))
    employee.tags << tag

    patch admin_employee_path(employee), params: {
      employee: {
        first_name: "Irene",
        last_name: "Mas",
        national_id: employee.national_id,
        active: "0",
        email: "irene@example.test"
      }
    }

    assert_redirected_to admin_employees_path
    employee.reload
    assert_equal "Irene", employee.first_name
    assert_equal "irene@example.test", employee.email
    assert_not employee.active?
    assert_empty employee.tags
  end

  test "updates an old employee while keeping national id omitted by disabled field" do
    employee = create_employee(first_name: "Iria", last_name: "Mas", national_id: valid_dni(41_000_011))
    employee.update_columns(created_at: 25.hours.ago)

    patch admin_employee_path(employee), params: {
      employee: {
        first_name: "Irene",
        last_name: "Mas",
        active: "0",
        email: "irene@example.test"
      }
    }

    assert_redirected_to admin_employees_path
    employee.reload
    assert_equal "Irene", employee.first_name
    assert_equal valid_dni(41_000_011), employee.national_id
    assert_equal "irene@example.test", employee.email
  end

  test "rejects national id changes for old employees" do
    employee = create_employee(first_name: "Iria", last_name: "Mas", national_id: valid_dni(41_000_012))
    employee.update_columns(created_at: 25.hours.ago)

    patch admin_employee_path(employee), params: {
      employee: {
        first_name: "Irene",
        last_name: "Mas",
        national_id: valid_dni(41_000_013),
        active: "1"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".error-summary li", text: "DNI no es pot canviar passades 24 hores de la creació"
    employee.reload
    assert_equal "Iria", employee.first_name
    assert_equal valid_dni(41_000_012), employee.national_id
  end

  test "activates and deactivates employees" do
    employee = create_employee(first_name: "Nora", last_name: "Vidal", national_id: valid_dni(41_000_008), active: true)

    patch activation_admin_employee_path(employee), params: { employee: { active: "false" } }

    assert_redirected_to admin_employees_path
    assert_not employee.reload.active?
    assert_equal "Persona desactivada.", flash[:notice]

    patch activation_admin_employee_path(employee), params: { employee: { active: "true" } }

    assert_redirected_to admin_employees_path
    assert_predicate employee.reload, :active?
    assert_equal "Persona activada.", flash[:notice]
  end
end
