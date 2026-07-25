require "test_helper"

class Admin::ClassificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "lists and filters classifications" do
    visible = Tag.create!(name: "Producció", color: "#16a34a", active: true)
    Tag.create!(name: "Oficina", color: "#2563eb", active: false)

    get admin_classifications_path, params: { q: "produ", status: "active" }

    assert_response :success
    assert_match "Producció", response.body
    assert_no_match "Oficina", response.body
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select "a.btn.admin-row-action[href='#{edit_admin_classification_path(visible)}'][aria-label='Editar'] svg.icon"
  end

  test "creates and updates a classification without deleting it" do
    assert_difference "Tag.count", 1 do
      post admin_classifications_path, params: {
        tag: { name: "Magatzem", color: "#16a34a", active: "1" }
      }
    end

    classification = Tag.order(:created_at).last
    assert_redirected_to admin_classifications_path
    assert_predicate classification, :active?

    patch admin_classification_path(classification), params: {
      tag: { name: "Magatzem intern", color: "#0f766e", active: "0" }
    }

    assert_redirected_to admin_classifications_path
    classification.reload
    assert_equal "Magatzem intern", classification.name
    assert_not classification.active?
  end
end
