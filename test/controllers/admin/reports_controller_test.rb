require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders empty reports placeholder" do
    get admin_reports_path

    assert_response :success
    assert_select "h1", text: "Informes"
    assert_match "Pàgina pendent.", response.body
    assert_select "[data-controller='list-loading']", 0
    assert_select "input[type='month']", 0
    assert_select "a[href='#']", 0
  end
end
