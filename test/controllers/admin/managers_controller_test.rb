require "test_helper"

class Admin::ManagersControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "lists and filters managers" do
    visible = create_manager(first_name: "Marta", last_name: "Serra", email: "marta.serra@example.test")
    create_manager(first_name: "Pau", last_name: "Vila", email: "pau.vila@example.test", active: false)
    visible.record_request_access!(at: Time.zone.local(2026, 7, 26, 10, 0))

    travel_to Time.zone.local(2026, 7, 26, 12, 0) do
      get admin_managers_path, params: { q: "marta", status: "active" }
    end

    assert_response :success
    assert_match "Marta Serra", response.body
    assert_no_match "Pau Vila", response.body
    assert_select "h2", text: "Filtres", count: 0
    assert_select "thead th", text: "Estat", count: 0
    assert_select "thead th:nth-child(1)", text: "Nom"
    assert_select "thead th:nth-child(3)", text: "Darrer accés"
    assert_select "thead th:nth-child(4)", text: "Accions"
    assert_select "form.admin-tags-filter-form[action='#{admin_managers_path}'][method='get']" do
      assert_select "input[type='search'][name='q'][value='marta'][placeholder='Nom, cognoms o correu']"
      assert_select "button[type='submit'][aria-label='Cercar'] svg.icon"
      assert_select "select[name='status']", count: 0
      assert_select "input[type='radio'][name='status'][value='']", count: 1
      assert_select "input[type='radio'][name='status'][value='active'][checked='checked']", count: 1
      assert_select "input[type='radio'][name='status'][value='disabled']", count: 1
      assert_select "label[for='manager_status_all']", text: "Tots"
      assert_select "label[for='manager_status_active']", text: "Actius"
      assert_select "label[for='manager_status_disabled']", text: "Inactius"
      assert_select "button", text: "Filtrar", count: 0
    end
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select ".text-center .admin-result-count", text: "Mostrant 1-1 de 1"
    assert_select "tbody tr.admin-manager-row.is-inactive", count: 0
    assert_select "tbody .admin-manager-name" do
      assert_select "svg.admin-manager-status-icon.is-active[aria-label='Actiu']"
      assert_select "strong", text: "Marta Serra"
    end
    assert_select "tbody td:nth-child(3)", text: "Fa 2 hores"
    assert_select "tbody td:nth-child(4)", text: "Actiu", count: 0
    activation_modal_id = "manager_activation_modal_#{visible.id}"
    assert_select "button.admin-row-action[data-bs-toggle='modal'][data-bs-target='##{activation_modal_id}'][aria-label='Desactivar responsable Marta Serra'] svg.icon"
    assert_select "##{activation_modal_id}.modal.fade[aria-labelledby='#{activation_modal_id}_label']" do
      assert_select "h2##{activation_modal_id}_label", text: "Desactivar responsable"
      assert_select ".modal-body", text: "Vols desactivar Marta Serra?"
      assert_select "form[action='#{activation_admin_manager_path(visible)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "input[name='manager[active]'][value='false']"
        assert_select "button[type='submit']", text: "Desactivar"
      end
    end
    assert_select "a.btn.admin-row-action[href='#{edit_admin_manager_path(visible)}'][aria-label='Editar'] svg.icon"

    get admin_managers_path, params: { q: "serra" }

    assert_response :success
    assert_match "Marta Serra", response.body
    assert_no_match "Pau Vila", response.body

    get admin_managers_path, params: { q: "marta.serra@example.test" }

    assert_response :success
    assert_match "Marta Serra", response.body
    assert_no_match "Pau Vila", response.body

    get admin_managers_path, params: { status: "disabled" }

    assert_response :success
    assert_match "Pau Vila", response.body
    assert_no_match "Marta Serra", response.body
    assert_select "tbody tr.admin-manager-row.is-inactive", count: 1
    assert_select "tbody .admin-manager-name" do
      assert_select "svg.admin-manager-status-icon.is-inactive[aria-label='Inactiu']"
      assert_select "strong", text: "Pau Vila"
    end
    assert_select "tbody td:nth-child(3)", text: "Mai"
    inactive = Manager.find_by!(email: "pau.vila@example.test")
    activation_modal_id = "manager_activation_modal_#{inactive.id}"
    assert_select "button.admin-row-action[data-bs-toggle='modal'][data-bs-target='##{activation_modal_id}'][aria-label='Activar responsable Pau Vila'] svg.icon"
    assert_select "##{activation_modal_id}.modal.fade[aria-labelledby='#{activation_modal_id}_label']" do
      assert_select "h2##{activation_modal_id}_label", text: "Activar responsable"
      assert_select ".modal-body", text: "Vols activar Pau Vila?"
      assert_select "form[action='#{activation_admin_manager_path(inactive)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "input[name='manager[active]'][value='true']"
        assert_select "button[type='submit']", text: "Activar"
      end
    end
  end

  test "renders manager form controls" do
    employee = create_employee(first_name: "Ona", last_name: "Prat")

    get new_admin_manager_path

    assert_response :success
    assert_select "label[for='manager_password']", text: "Contrasenya"
    assert_select "label", text: /deixar en blanc per no modificar/, count: 0
    assert_select ".col-12.col-md-6 .admin-employee-search[data-controller='employee-search']" do
      assert_select "input[type='hidden'][name='manager[employee_id]'][value='']"
    end
    assert_select ".admin-employee-search[data-controller='employee-search'][data-employee-search-url-value='#{admin_employee_search_path}'][data-employee-search-auto-submit-value='false']" do
      assert_select "input[name='manager_employee_query'][placeholder='Cerca per nom, DNI, correu o telèfon'][role='combobox']"
      assert_select "button[type='button'][aria-label='Sense treballador vinculat'][data-action='employee-search#clear'] svg.icon"
    end
    assert_select "select[name='manager[employee_id]']", count: 0
    assert_select "select[name='manager[active]']", count: 0
    assert_select "fieldset.col-12.col-md-6.admin-status-radio-fieldset" do
      assert_select "legend.form-label", text: "Estat"
      assert_select ".admin-status-radio-group.btn-group.w-100" do
        assert_select "input[type='radio'][name='manager[active]'][value='true'][checked='checked'] + label.admin-status-radio-option.is-active" do
          assert_select "svg.admin-status-radio-icon"
          assert_select "span", text: "Actiu"
        end
        assert_select "input[type='radio'][name='manager[active]'][value='false'] + label.admin-status-radio-option.is-inactive" do
          assert_select "svg.admin-status-radio-icon"
          assert_select "span", text: "Inactiu"
        end
      end
    end
    assert_select "input[type='radio'][name='manager[active]'][value='false']"

    manager = create_manager(employee: employee, active: false)

    get edit_admin_manager_path(manager)

    assert_response :success
    assert_select "label[for='manager_password']", text: "Contrasenya (deixar en blanc per no modificar)"
    assert_select "input[type='hidden'][name='manager[employee_id]'][value='#{employee.id}']"
    assert_select "input[name='manager_employee_query'][value='Ona Prat']"
    assert_select "input[type='radio'][name='manager[active]'][value='false'][checked='checked']"
  end

  test "edit page keeps layout identity on the signed in manager" do
    signed_in_manager = create_manager(
      first_name: "Sessio",
      last_name: "Actual",
      email: "signed.in.manager@example.test"
    )
    edited_manager = create_manager(
      first_name: "Responsable",
      last_name: "Editat",
      email: "edited.manager@example.test"
    )
    log_in_manager(signed_in_manager)

    get edit_admin_manager_path(edited_manager)

    assert_response :success
    assert_select "a[href='#{admin_account_path}'] span", text: "Sessio Actual", count: 2
    assert_select "a[href='#{admin_account_path}'] span", text: "Responsable Editat", count: 0
    assert_select "input[name='manager[first_name]'][value='Responsable']"
    assert_select "input[name='manager[last_name]'][value='Editat']"
  end

  test "renders validation error when linked employee already has a manager" do
    employee = create_employee(first_name: "Ona", last_name: "Prat")
    create_manager(employee: employee, email: "first.manager@example.test")
    manager = create_manager(email: "second.manager@example.test")

    patch admin_manager_path(manager), params: {
      manager: {
        first_name: manager.first_name,
        last_name: manager.last_name,
        email: manager.email,
        employee_id: employee.id,
        active: "1",
        password: ""
      }
    }

    assert_response :unprocessable_entity
    assert_no_match "Aquesta treballadora ja està vinculada a un altre responsable.", response.body
    assert_select ".error-summary", count: 1
    assert_select ".error-summary li", text: "Treballador vinculat ja està assignat a un altre responsable"
    assert_nil manager.reload.employee
  end

  test "employee search endpoint matches employees by name and contact fields" do
    employee = create_employee(
      first_name: "Mireia",
      last_name: "Bosch",
      national_id: valid_dni(41_000_001),
      email: "mireia.bosch@example.test",
      phone: "+34 600 111 222",
      active: false
    )
    create_employee(
      first_name: "Pau",
      last_name: "Vila",
      national_id: valid_dni(41_000_002),
      email: "pau.vila@example.test",
      phone: "+34 600 333 444"
    )

    get admin_employee_search_path, params: { q: "Mireia", selected_employee_id: employee.id }

    assert_response :success
    assert_select ".admin-employee-search-result.active[data-employee-search-id-param='#{employee.id}'][aria-selected='true']",
      text: /Mireia Bosch\s+-\s+#{employee.national_id}/
    assert_no_match "Pau Vila", response.body
    assert_no_match employee.email, response.body
    assert_no_match employee.phone, response.body

    get admin_employee_search_path, params: { q: "600111222" }

    assert_response :success
    assert_select ".admin-employee-search-result[data-employee-search-id-param='#{employee.id}']"
  end

  test "creates and updates a manager without deleting it" do
    employee = create_employee(first_name: "Ona", last_name: "Prat")

    assert_difference "Manager.count", 1 do
      post admin_managers_path, params: {
        manager: {
          first_name: "Arnau",
          last_name: "Mas",
          email: "arnau.mas@example.test",
          employee_id: employee.id,
          active: "1",
          password: "secret123"
        }
      }
    end

    manager = Manager.order(:created_at).last
    assert_redirected_to admin_managers_path
    assert_equal employee, manager.employee
    assert manager.authenticate_password("secret123")

    patch admin_manager_path(manager), params: {
      manager: {
        first_name: "Arnau",
        last_name: "Mas",
        email: "arnau.mas@example.test",
        employee_id: "",
        active: "0",
        password: ""
      }
    }

    assert_redirected_to admin_managers_path
    manager.reload
    assert_nil manager.employee
    assert_not manager.active?
    assert manager.authenticate_password("secret123")
  end

  test "activates and deactivates managers" do
    manager = create_manager(first_name: "Marta", last_name: "Serra", email: "marta.serra@example.test", active: true)

    patch activation_admin_manager_path(manager), params: { manager: { active: "false" } }

    assert_redirected_to admin_managers_path
    assert_not manager.reload.active?
    assert_equal "Responsable desactivat.", flash[:notice]

    patch activation_admin_manager_path(manager), params: { manager: { active: "true" } }

    assert_redirected_to admin_managers_path
    assert_predicate manager.reload, :active?
    assert_equal "Responsable activat.", flash[:notice]
  end
end
