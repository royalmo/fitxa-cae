require "test_helper"

class Admin::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @manager = create_manager(
      first_name: "Laia",
      last_name: "Riera",
      email: "laia.account@example.test",
      password: "12345678"
    )
    log_in_manager(@manager)
  end

  test "renders account forms" do
    get admin_account_path

    assert_response :success
    assert_select "title", text: "Compte | FitxaCAE Admin"
    assert_select "h1", text: "Compte de responsable"
    assert_select "form[action='#{admin_account_profile_path}']"
    assert_select "input[name='manager[first_name]'][disabled='disabled'][title='Edita aquests camps des de la pàgina de responsables']"
    assert_select "input[name='manager[last_name]'][disabled='disabled'][title='Edita aquests camps des de la pàgina de responsables']"
    assert_select "input[name='manager[email]']:not([disabled])"
    assert_select "form[action='#{admin_account_password_path}']"
    assert_select "button[type='submit'][data-submitting-label='Desant...']"
    assert_select "button[type='submit'][data-submitting-label='Canviant...']"
  end

  test "updates profile email only" do
    patch admin_account_profile_path, params: {
      manager: {
        first_name: "Lia",
        last_name: "Costa",
        email: "LIA.RIERA@EXAMPLE.TEST"
      }
    }

    assert_redirected_to admin_account_path
    @manager.reload
    assert_equal "Laia", @manager.first_name
    assert_equal "Riera", @manager.last_name
    assert_equal "lia.riera@example.test", @manager.email
  end

  test "updates password" do
    patch admin_account_password_path, params: {
      manager: {
        password: "new-secret",
        password_confirmation: "new-secret"
      }
    }

    assert_redirected_to admin_account_path
    assert @manager.reload.authenticate_password("new-secret")
  end

  test "renders password errors" do
    patch admin_account_password_path, params: {
      manager: {
        password: "new-secret",
        password_confirmation: "different"
      }
    }

    assert_response :unprocessable_entity
    assert_select ".error-summary"
    assert_not @manager.reload.authenticate_password("new-secret")
  end
end
