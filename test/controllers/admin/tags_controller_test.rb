require "test_helper"

class Admin::TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "lists and filters tags" do
    visible = Tag.create!(name: "Producció", color: "#16a34a", active: true)
    inactive = Tag.create!(name: "Oficina", color: "#2563eb", active: false)
    visible.employees << create_employee(first_name: "Ada", national_id: valid_dni(51_000_001))
    visible.employees << create_employee(first_name: "Jana", national_id: valid_dni(51_000_002))
    inactive.employees << create_employee(first_name: "Ona", national_id: valid_dni(51_000_003))

    get admin_tags_path, params: { q: "produ", status: "active" }

    assert_response :success
    assert_equal "/admin/tags", path
    assert_match "Producció", response.body
    assert_no_match "Oficina", response.body
    assert_select "h2", text: "Filtres", count: 0
    assert_select "button.btn-primary[data-bs-toggle='modal'][data-bs-target='#tag_form_modal_new']", text: "Nova etiqueta"
    assert_select "th", text: "Color", count: 0
    assert_select ".admin-color-swatch", count: 0
    assert_select "thead th:nth-child(1).admin-tags-status-column", text: "Estat"
    assert_select "thead th:nth-child(2)", text: "Nom"
    assert_select "thead th:nth-child(3):not(.text-center)", text: "Treballadores"
    assert_select "thead th:nth-child(4)", text: "Accions"
    assert_select "#tag_form_modal_new.modal.fade[data-controller='bootstrap-modal']" do
      assert_select "h2#tag_form_modal_new_label", text: "Nova etiqueta"
      assert_select "form.admin-tag-form[action='#{admin_tags_path}'][method='post']" do
        assert_select ".admin-tag-form-field.row.align-items-center", count: 2
        assert_select ".admin-tag-form-field .col-3 label.col-form-label", count: 2
        assert_select ".admin-tag-form-field .col-9 input", count: 2
        assert_select "input[name='tag[name]']", count: 1
        assert_select "input[type='color'][name='tag[color]'][value='#e30613']", count: 1
        assert_select "input[name='tag[active]']", count: 0
      end
    end
    assert_select "form[action='#{admin_tags_path}'][method='get']" do
      assert_select "input[type='search'][name='q'][value='produ']"
      assert_select "button[type='submit'][aria-label='Cercar'] svg.icon"
      assert_select "select[name='status']", count: 0
      assert_select "input[type='radio'][name='status'][value='']", count: 1
      assert_select "input[type='radio'][name='status'][value='active'][checked='checked']", count: 1
      assert_select "input[type='radio'][name='status'][value='disabled']", count: 1
      assert_select "label[for='tag_status_all']", text: "Totes"
      assert_select "label[for='tag_status_active']", text: "Actives"
      assert_select "label[for='tag_status_disabled']", text: "Inactives"
      assert_select "button", text: "Filtrar", count: 0
    end
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select ".text-center .admin-result-count", text: "Mostrant 1-1 de 1"
    tag_label = css_select("tbody .admin-tag-label").first
    assert_equal "Producció", tag_label.text.strip
    assert_includes tag_label["style"], "--admin-tag-bg: #16a34a"
    assert_includes tag_label["style"], "--admin-tag-color: #111827"
    assert_select "tbody .admin-tag-label svg.admin-tag-label-icon + span", text: "Producció"
    assert_select "tbody .admin-tag-status.badge", count: 0
    assert_select "tbody .admin-tag-status.is-active", text: "Activa", count: 1
    assert_select "tbody td:nth-child(1).admin-tags-status-column .admin-tag-status svg.admin-badge-icon + span", text: "Activa"
    assert_select "tbody tr.admin-tag-row.is-inactive", count: 0
    assert_select "tbody td:nth-child(3):not(.text-center) a.admin-tag-employees-count[href='#{admin_employees_path(tag_id: visible.id)}'][aria-label=\"Veure 2 treballadors amb l'etiqueta Producció\"]" do
      assert_select "svg.admin-tag-employees-count-icon"
      assert_select "span", text: "2"
    end
    activation_modal_id = "tag_activation_modal_#{visible.id}"
    assert_select "button.admin-row-action[data-bs-toggle='modal'][data-bs-target='##{activation_modal_id}'][aria-label='Desactivar etiqueta Producció'] svg.icon"
    assert_select "##{activation_modal_id}.modal.fade[aria-labelledby='#{activation_modal_id}_label']" do
      assert_select "h2##{activation_modal_id}_label", text: "Desactivar etiqueta"
      assert_select ".modal-body .admin-tag-label svg.admin-tag-label-icon + span", text: "Producció"
      assert_select ".modal-body", text: /Aquesta etiqueta no es podrà assignar a cap treballadora/
      assert_select "form[action='#{activation_admin_tag_path(visible)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "input[name='tag[active]'][value='false']"
        assert_select "button[type='submit']", text: "Desactivar"
      end
    end
    edit_modal_id = "tag_form_modal_#{visible.id}"
    assert_select "button.admin-row-action[data-bs-toggle='modal'][data-bs-target='##{edit_modal_id}'][aria-label='Editar etiqueta Producció'] svg.icon"
    assert_select "##{edit_modal_id}.modal.fade[data-controller='bootstrap-modal']" do
      assert_select "h2##{edit_modal_id}_label", text: "Editar etiqueta"
      assert_select "form.admin-tag-form[action='#{admin_tag_path(visible)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "input[name='tag[name]'][value='Producció']"
        assert_select "input[type='color'][name='tag[color]'][value='#16a34a']"
        assert_select "input[name='tag[active]']", count: 0
      end
    end

    get admin_tags_path, params: { status: "disabled" }

    assert_response :success
    assert_match "Oficina", response.body
    tag_label = css_select("tbody .admin-tag-label").first
    assert_equal "Oficina", tag_label.text.strip
    assert_includes tag_label["style"], "--admin-tag-bg: #2563eb"
    assert_includes tag_label["style"], "--admin-tag-color: #ffffff"
    assert_select "tbody .admin-tag-label svg.admin-tag-label-icon + span", text: "Oficina"
    assert_select "tbody .admin-tag-status.badge", count: 0
    assert_select "tbody .admin-tag-status.is-inactive", text: "Inactiva", count: 1
    assert_select "tbody td:nth-child(1).admin-tags-status-column .admin-tag-status svg.admin-badge-icon + span", text: "Inactiva"
    assert_select "tbody tr.admin-tag-row.is-inactive", count: 1
    assert_select "tbody td:nth-child(3):not(.text-center) a.admin-tag-employees-count[href='#{admin_employees_path(tag_id: inactive.id)}'][aria-label=\"Veure 1 treballador amb l'etiqueta Oficina\"]" do
      assert_select "svg.admin-tag-employees-count-icon"
      assert_select "span", text: "1"
    end
    activation_modal_id = "tag_activation_modal_#{inactive.id}"
    assert_select "button.admin-row-action[data-bs-toggle='modal'][data-bs-target='##{activation_modal_id}'][aria-label='Activar etiqueta Oficina'] svg.icon"
    assert_select "##{activation_modal_id}.modal.fade[aria-labelledby='#{activation_modal_id}_label']" do
      assert_select "h2##{activation_modal_id}_label", text: "Activar etiqueta"
      assert_select ".modal-body .admin-tag-label svg.admin-tag-label-icon + span", text: "Oficina"
      assert_select ".modal-body", text: /la tornaran a veure/
      assert_select "form[action='#{activation_admin_tag_path(inactive)}'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
        assert_select "input[name='tag[active]'][value='true']"
        assert_select "button[type='submit']", text: "Activar"
      end
    end
  end

  test "creates and updates a tag without deleting it" do
    assert_difference "Tag.count", 1 do
      post admin_tags_path, params: {
        tag: { name: "Magatzem", color: "#16a34a", active: "0" }
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
    assert_equal "#0f766e", tag.color
    assert_predicate tag, :active?
  end

  test "shows validation errors in tag form modal" do
    assert_no_difference "Tag.count" do
      post admin_tags_path, params: { tag: { name: "", color: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "#tag_form_modal_new[data-bootstrap-modal-show-value='true']" do
      assert_select ".error-summary", text: /Revisa l'etiqueta/
      assert_select "input[name='tag[active]']", count: 0
    end
  end

  test "shows translated tag attribute names in validation errors" do
    Tag.create!(name: "Acollida", color: "#16a34a")

    assert_no_difference "Tag.count" do
      post admin_tags_path, params: { tag: { name: "acollida", color: "#2563eb" } }
    end

    assert_response :unprocessable_entity
    assert_select "#tag_form_modal_new[data-bootstrap-modal-show-value='true']" do
      assert_select ".error-summary li", text: "Nom ja està assignat a una altra etiqueta"
    end
  end

  test "activates and deactivates tags" do
    tag = Tag.create!(name: "Producció", color: "#16a34a", active: true)

    patch activation_admin_tag_path(tag), params: { tag: { active: "false" } }

    assert_redirected_to admin_tags_path
    assert_not tag.reload.active?
    assert_equal "Etiqueta desactivada.", flash[:notice]

    patch activation_admin_tag_path(tag), params: { tag: { active: "true" } }

    assert_redirected_to admin_tags_path
    assert_predicate tag.reload, :active?
    assert_equal "Etiqueta activada.", flash[:notice]
  end
end
