require "test_helper"

class Admin::EmployeesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "lists employees from the database" do
    tag = Tag.create!(name: "office", active: true, color: "#2563eb")
    employee = create_employee(first_name: "Nora", last_name: "Vidal", email: "nora@example.test")
    employee.tags << tag

    get admin_employees_path

    assert_response :success
    assert_match "Nora Vidal", response.body
    assert_match "nora@example.test", response.body
    assert_match "office", response.body
    assert_select "[data-controller='list-loading']"
    assert_select ".admin-result-count[data-list-loading-target='results']",
      text: "Mostrant 1-#{[ Employee.count, 20 ].min} de #{Employee.count}"
    assert_select "button[type='submit'][data-submitting-label='Filtrant...'] svg.icon"
    assert_select "a.btn.admin-row-action[href='#{edit_admin_employee_path(employee)}'][aria-label='Editar'] svg.icon"
    assert_select ".admin-status-badge svg.admin-badge-icon"
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

  test "creates an employee with tags and optional password" do
    tag = Tag.create!(name: "office", active: true, color: "#2563eb")

    assert_difference "Employee.count", 1 do
      post admin_employees_path, params: {
        employee: {
          first_name: "Pau",
          last_name: "Costa",
          national_id: valid_dni(41_000_003),
          email: "pau@example.test",
          phone: "+34 600 111 222",
          active: "1",
          password: "1234",
          tag_ids: [ tag.id ]
        }
      }
    end

    assert_redirected_to admin_employees_path
    employee = Employee.last
    assert_equal [ tag ], employee.tags.to_a
    assert employee.authenticate("1234")
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
end
