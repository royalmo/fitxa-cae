require "test_helper"

class Admin::ManagersControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "lists and filters managers" do
    visible = create_manager(first_name: "Marta", last_name: "Serra", email: "marta.serra@example.test")
    create_manager(first_name: "Pau", last_name: "Vila", email: "pau.vila@example.test", active: false)

    get admin_managers_path, params: { q: "marta", status: "active" }

    assert_response :success
    assert_match "Marta Serra", response.body
    assert_no_match "Pau Vila", response.body
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select "a.btn.admin-row-action[href='#{edit_admin_manager_path(visible)}'][aria-label='Editar'] svg.icon"
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
end
