require "test_helper"

class Admin::TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "lists and filters tags" do
    visible = Tag.create!(name: "Producció", color: "#16a34a", active: true)
    Tag.create!(name: "Oficina", color: "#2563eb", active: false)

    get admin_tags_path, params: { q: "produ", status: "active" }

    assert_response :success
    assert_equal "/admin/tags", path
    assert_match "Producció", response.body
    assert_no_match "Oficina", response.body
    assert_select "h2", text: "Filtres", count: 0
    assert_select "a[href='#{new_admin_tag_path}']", text: "Nova etiqueta"
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select ".text-center .admin-result-count", text: "Mostrant 1-1 de 1"
    assert_select "a.btn.admin-row-action[href='#{edit_admin_tag_path(visible)}'][aria-label='Editar'] svg.icon"
  end

  test "creates and updates a tag without deleting it" do
    assert_difference "Tag.count", 1 do
      post admin_tags_path, params: {
        tag: { name: "Magatzem", color: "#16a34a", active: "1" }
      }
    end

    tag = Tag.order(:created_at).last
    assert_redirected_to admin_tags_path
    assert_predicate tag, :active?

    patch admin_tag_path(tag), params: {
      tag: { name: "Magatzem intern", color: "#0f766e", active: "0" }
    }

    assert_redirected_to admin_tags_path
    tag.reload
    assert_equal "Magatzem intern", tag.name
    assert_not tag.active?
  end
end
