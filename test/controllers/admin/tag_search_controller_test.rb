require "test_helper"

class Admin::TagSearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "searches active tags by name" do
    selected_tag = Tag.create!(name: "Producció", color: "#16a34a", active: true)
    Tag.create!(name: "Oficina", color: "#2563eb", active: false)
    Tag.create!(name: "Magatzem", color: "#e30613", active: true)

    get admin_tag_search_path, params: { q: "prod", selected_tag_id: selected_tag.id }

    assert_response :success
    assert_select ".admin-tag-search-result.active[data-tag-search-id-param='#{selected_tag.id}'][data-tag-search-label-param='Producció'][aria-selected='true']" do
      assert_select ".admin-tag-label svg.admin-tag-label-icon + span", text: "Producció"
    end
    assert_select ".admin-tag-search-result[data-tag-search-style-param*='#16a34a']"
    assert_no_match "Oficina", response.body
    assert_no_match "Magatzem", response.body
  end

  test "does not return inactive tags" do
    active_tag = Tag.create!(name: "Activa", color: "#16a34a", active: true)
    Tag.create!(name: "Inactiva", color: "#2563eb", active: false)

    get admin_tag_search_path

    assert_response :success
    assert_select ".admin-tag-search-result[data-tag-search-id-param='#{active_tag.id}']"
    assert_no_match "Inactiva", response.body
  end

  test "shows no results message" do
    Tag.create!(name: "Producció", color: "#16a34a", active: true)

    get admin_tag_search_path, params: { q: "cap etiqueta" }

    assert_response :success
    assert_select ".list-group-item.text-body-secondary", text: "Cap etiqueta activa trobada."
  end
end
