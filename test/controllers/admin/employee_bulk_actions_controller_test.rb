require "test_helper"

class Admin::EmployeeBulkActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders activation bulk action page" do
    get bulk_activation_admin_employees_path

    assert_response :success
    assert_select "title", text: "Activar i desactivar | FitxaCAE Admin"
    assert_select "h1", text: "Activar i desactivar"
    assert_select "a[href='#{admin_employees_path}']", text: "Tornar a persones"
  end

  test "renders tag bulk action page" do
    get bulk_tags_admin_employees_path

    assert_response :success
    assert_select "title", text: "Afegir etiquetes | FitxaCAE Admin"
    assert_select "h1", text: "Afegir etiquetes"
    assert_select "a[href='#{admin_employees_path}']", text: "Tornar a persones"
  end
end
