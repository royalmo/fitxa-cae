require "test_helper"

class Admin::EmployeeBulkActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders activation bulk action page" do
    get bulk_activation_admin_employees_path

    assert_response :success
    assert_select "title", text: "Activar i desactivar massivament | FitxaCAE Admin"
    assert_select "h1", text: "Activar i desactivar massivament"
    assert_select "a.btn.border-0[href='#{admin_employees_path}']", text: "Tornar"
    assert_select ".admin-bulk-action[data-controller='bulk-national-ids'][data-bulk-national-ids-simulate-url-value='#{simulate_bulk_activation_admin_employees_path}'][data-bulk-national-ids-run-no-affected-label-value='Aquesta acció no afectarà cap persona.']" do
      assert_select "form[action='#{run_bulk_activation_admin_employees_path}'][method='post']" do
        assert_select ".admin-bulk-action-layout" do
          assert_select ".admin-bulk-action-form-card.card.shadow-sm > .card-body.admin-bulk-action-form" do
            assert_select ".admin-bulk-action-options[role='group'] > .admin-bulk-action-label", text: "Acció"
            assert_select "textarea#admin_bulk_national_ids[name='national_ids_text'][data-bulk-national-ids-target='textarea']"
            assert_select "label[for='admin_bulk_national_ids']",
              text: "Llistat de DNI/NIEs, separat per espai, coma, o un per línia."
            assert_select ".form-text", count: 0
            assert_select "input[type='radio'][name='bulk_action[action]'][checked]", count: 0
            assert_select "input[type='radio'][name='bulk_action[action]'][value='activate'][autocomplete='off'] + label",
              text: "Activar"
            assert_select "input[type='radio'][name='bulk_action[action]'][value='deactivate'][autocomplete='off'] + label",
              text: "Desactivar"
            assert_select "[data-bulk-national-ids-target='simulateTooltip'][data-bs-toggle='tooltip'][data-bs-placement='top']" do
              assert_select "button[type='button'][disabled][data-bulk-national-ids-target='simulateButton']", text: "Simular"
            end
            assert_select ".alert.alert-danger.alert-dismissible[role='alert'][data-bulk-national-ids-target='error'][hidden]" do
              assert_select "button.btn-close[type='button'][aria-label='Tancar avís'][data-action='bulk-national-ids#dismissError']"
            end
          end
          assert_select ".admin-bulk-simulation-results.card.shadow-sm.is-disabled[aria-disabled='true'][data-bulk-national-ids-target='results']" do
            assert_select "> .card-body"
            assert_select "h2", text: "Simulació"
            assert_select ".admin-bulk-simulation-kpis > div", count: 2
            assert_select ".admin-bulk-simulation-kpis dt", text: "DNI/NIEs trobats"
            assert_select ".admin-bulk-simulation-kpis dt", text: "Persones actives"
            assert_select "[data-bulk-national-ids-target='foundRatio']", text: "0/0"
            assert_select "[data-bulk-national-ids-target='activeRatio']", text: "0/0"
            assert_select ".admin-bulk-affected-summary", text: /Aquesta acció afectarà a\s+0\s+persones\./
            assert_select ".admin-bulk-affected-summary .text-primary[data-bulk-national-ids-target='affectedCount']",
              text: "0"
            assert_select ".admin-bulk-disabled-button-tooltip.is-disabled[data-bulk-national-ids-target='runTooltip'][data-bs-toggle='tooltip'][data-bs-placement='top']" do
              assert_select "button[type='button'][disabled][data-bulk-national-ids-target='runButton']",
                text: "Executar acció massiva"
            end
          end
        end
        assert_select "[data-bulk-national-ids-target='results'][hidden]", count: 0
        assert_select "#adminEmployeeBulkActivationConfirmModal.modal.fade" do
          assert_select ".modal-title", text: "Executar acció massiva"
          assert_select "button[type='submit']", text: "Sí, executar"
        end
      end
    end
    assert_select "a[href='#{admin_employees_path}']", text: "Tornar a persones", count: 0
  end

  test "renders tag bulk action page" do
    get bulk_tags_admin_employees_path

    assert_response :success
    assert_select "title", text: "Afegir etiquetes | FitxaCAE Admin"
    assert_select "h1", text: "Afegir etiquetes"
    assert_select "a.btn.border-0[href='#{admin_employees_path}']", text: "Tornar"
    assert_select ".admin-bulk-action[data-controller='bulk-tags'][data-bulk-tags-simulate-url-value='#{simulate_bulk_tags_admin_employees_path}']" do
      assert_select "form[action='#{run_bulk_tags_admin_employees_path}'][method='post']" do
        assert_select ".admin-bulk-action-form-card" do
          assert_select "legend.form-label", text: "Etiquetes a afegir"
          assert_select "legend.form-label", text: "Etiquetes a treure"
          assert_select ".admin-tag-multi-search[data-controller='tag-multi-search']", count: 2
          assert_select ".admin-tag-multi-search-selections > .admin-tag-multi-search-selection", count: 0
          assert_select "input.admin-tag-multi-search-input[name='bulk_add_tag_query'][placeholder='Cerca etiquetes per afegir']"
          assert_select "input.admin-tag-multi-search-input[name='bulk_remove_tag_query'][placeholder='Cerca etiquetes per treure']"
          assert_select "textarea#admin_bulk_tag_national_ids[name='national_ids_text'][data-bulk-tags-target='textarea']"
          assert_select "input[type='checkbox'][name='bulk_tags[include_inactive]'][data-bulk-tags-target='includeInactive']:not([checked])"
          assert_select "label", text: "Incloure persones inactives"
          assert_select "button[type='button'][disabled][data-bulk-tags-target='simulateButton']", text: "Simular"
        end
        assert_select ".admin-bulk-simulation-results.card.shadow-sm.is-disabled[data-bulk-tags-target='results']" do
          assert_select "[data-bulk-tags-target='foundRatio']", text: "0/0"
          assert_select "[data-bulk-tags-target='tagKpis']"
          assert_select ".admin-bulk-affected-summary .text-primary[data-bulk-tags-target='affectedCount']", text: "0"
          assert_select "button[type='button'][disabled][data-bulk-tags-target='runButton']", text: "Executar acció massiva"
        end
        assert_select "#adminEmployeeBulkTagsConfirmModal.modal.fade" do
          assert_select ".modal-title", text: "Executar acció massiva"
          assert_select "button[type='submit']", text: "Sí, executar"
        end
      end
    end
    assert_select "a[href='#{admin_employees_path}']", text: "Tornar a persones", count: 0
  end

  test "simulates activation states for national ids" do
    active_employee = create_employee(national_id: valid_dni(44_000_001), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_000_002), active: false)

    post simulate_bulk_activation_admin_employees_path,
      params: { national_ids: [ active_employee.national_id, inactive_employee.national_id, valid_dni(44_000_003) ] },
      as: :json

    assert_response :success
    assert_equal({
      active_employee.national_id => true,
      inactive_employee.national_id => false
    }, JSON.parse(response.body))
  end

  test "rejects invalid activation simulation payloads" do
    post simulate_bulk_activation_admin_employees_path, params: { national_ids: "bad" }, as: :json

    assert_response :unprocessable_entity
    assert_equal "La llista de DNI/NIE no és vàlida.", JSON.parse(response.body).fetch("error")

    post simulate_bulk_activation_admin_employees_path, params: { national_ids: [ valid_dni(44_000_010), "bad" ] }, as: :json

    assert_response :unprocessable_entity
    assert_equal "No s'ha pogut simular la llista. Primer DNI/NIE no vàlid: BAD.",
      JSON.parse(response.body).fetch("error")
  end

  test "rejects duplicated national ids in activation simulation payloads" do
    duplicated_national_id = valid_dni(44_000_012)

    post simulate_bulk_activation_admin_employees_path,
      params: { national_ids: [ duplicated_national_id, valid_dni(44_000_013), duplicated_national_id.downcase ] },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "No s'ha pogut simular la llista. El DNI/NIE #{duplicated_national_id} està duplicat 2 vegades.",
      JSON.parse(response.body).fetch("error")
  end

  test "simulates bulk tag changes for active employees by default" do
    add_tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    remove_tag = Tag.create!(name: "Warehouse", color: "#16a34a", active: true)
    active_employee = create_employee(national_id: valid_dni(44_100_001), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_100_002), active: false)
    active_employee.tags << remove_tag
    inactive_employee.tags << remove_tag

    post simulate_bulk_tags_admin_employees_path,
      params: {
        national_ids: [ active_employee.national_id, inactive_employee.national_id, valid_dni(44_100_003) ],
        bulk_tags: { add_tag_ids: [ add_tag.id ], remove_tag_ids: [ remove_tag.id ], include_inactive: "0" }
      },
      as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 3, payload.fetch("total_count")
    assert_equal 1, payload.fetch("found_count")
    assert_equal 1, payload.fetch("affected_count")
    add_payload = payload.fetch("tags").find { |tag| tag.fetch("id") == add_tag.id }
    remove_payload = payload.fetch("tags").find { |tag| tag.fetch("id") == remove_tag.id }
    assert_equal 0, add_payload.fetch("count")
    assert_includes add_payload.fetch("html"), "Office"
    assert_equal 1, remove_payload.fetch("count")
    assert_includes remove_payload.fetch("html"), "Warehouse"
  end

  test "simulates bulk tag changes including inactive employees when requested" do
    remove_tag = Tag.create!(name: "Warehouse", color: "#16a34a", active: true)
    active_employee = create_employee(national_id: valid_dni(44_100_004), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_100_005), active: false)
    active_employee.tags << remove_tag
    inactive_employee.tags << remove_tag

    post simulate_bulk_tags_admin_employees_path,
      params: {
        national_ids: [ active_employee.national_id, inactive_employee.national_id ],
        bulk_tags: { remove_tag_ids: [ remove_tag.id ], include_inactive: "1" }
      },
      as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 2, payload.fetch("total_count")
    assert_equal 2, payload.fetch("found_count")
    assert_equal 2, payload.fetch("affected_count")
    assert_equal 2, payload.fetch("tags").first.fetch("count")
  end

  test "rejects conflicting bulk tag simulation selections" do
    tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    employee = create_employee(national_id: valid_dni(44_100_006), active: true)

    post simulate_bulk_tags_admin_employees_path,
      params: {
        national_ids: [ employee.national_id ],
        bulk_tags: { add_tag_ids: [ tag.id ], remove_tag_ids: [ tag.id ] }
      },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "No pots afegir i treure la mateixa etiqueta.", JSON.parse(response.body).fetch("error")
  end

  test "runs bulk tag changes for active employees by default" do
    add_tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    remove_tag = Tag.create!(name: "Warehouse", color: "#16a34a", active: true)
    active_employee = create_employee(national_id: valid_dni(44_100_007), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_100_008), active: false)
    active_employee.tags << remove_tag
    inactive_employee.tags << remove_tag

    post run_bulk_tags_admin_employees_path, params: {
      national_ids: [ active_employee.national_id, inactive_employee.national_id ],
      bulk_tags: { add_tag_ids: [ add_tag.id ], remove_tag_ids: [ remove_tag.id ], include_inactive: "0" }
    }

    assert_redirected_to admin_employees_path
    assert_includes active_employee.reload.tags, add_tag
    assert_not_includes active_employee.tags, remove_tag
    assert_not_includes inactive_employee.reload.tags, add_tag
    assert_includes inactive_employee.tags, remove_tag
    assert_equal "S'han actualitzat les etiquetes d'1 persona.", flash[:notice]
  end

  test "redirects bulk tag changes with no affected employees" do
    tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    employee = create_employee(national_id: valid_dni(44_100_009), active: true)
    employee.tags << tag

    post run_bulk_tags_admin_employees_path, params: {
      national_ids: [ employee.national_id ],
      bulk_tags: { add_tag_ids: [ tag.id ] }
    }

    assert_redirected_to bulk_tags_admin_employees_path
    assert_equal "Aquesta acció no afectarà cap persona.", flash[:alert]
  end

  test "runs activation bulk action" do
    active_employee = create_employee(national_id: valid_dni(44_000_004), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_000_005), active: false)

    post run_bulk_activation_admin_employees_path, params: {
      national_ids: [ active_employee.national_id, inactive_employee.national_id, valid_dni(44_000_006) ],
      bulk_action: { action: "activate" }
    }

    assert_redirected_to admin_employees_path
    assert_predicate active_employee.reload, :active?
    assert_predicate inactive_employee.reload, :active?
    assert_equal "S'ha activat 1 persona.", flash[:notice]
  end

  test "runs deactivation bulk action" do
    active_employee = create_employee(national_id: valid_dni(44_000_007), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_000_008), active: false)

    post run_bulk_activation_admin_employees_path, params: {
      national_ids: [ active_employee.national_id, inactive_employee.national_id ],
      bulk_action: { action: "deactivate" }
    }

    assert_redirected_to admin_employees_path
    assert_not active_employee.reload.active?
    assert_not inactive_employee.reload.active?
    assert_equal "S'ha desactivat 1 persona.", flash[:notice]
  end

  test "redirects activation bulk actions with no affected employees" do
    employee = create_employee(national_id: valid_dni(44_000_016), active: true)

    post run_bulk_activation_admin_employees_path, params: {
      national_ids: [ employee.national_id ],
      bulk_action: { action: "activate" }
    }

    assert_redirected_to bulk_activation_admin_employees_path
    assert_predicate employee.reload, :active?
    assert_equal "Aquesta acció no afectarà cap persona.", flash[:alert]
  end

  test "redirects invalid activation bulk action requests" do
    employee = create_employee(national_id: valid_dni(44_000_009), active: true)

    post run_bulk_activation_admin_employees_path, params: {
      national_ids: [ employee.national_id ],
      bulk_action: { action: "" }
    }

    assert_redirected_to bulk_activation_admin_employees_path
    assert_predicate employee.reload, :active?
    assert_equal "Revisa la llista de DNI/NIE i l'acció seleccionada.", flash[:alert]
  end

  test "redirects activation bulk actions with the first invalid national id" do
    post run_bulk_activation_admin_employees_path, params: {
      national_ids: [ valid_dni(44_000_011), "bad" ],
      bulk_action: { action: "activate" }
    }

    assert_redirected_to bulk_activation_admin_employees_path
    assert_equal "No s'ha pogut simular la llista. Primer DNI/NIE no vàlid: BAD.", flash[:alert]
  end

  test "redirects activation bulk actions with the first duplicated national id" do
    duplicated_national_id = valid_dni(44_000_014)

    post run_bulk_activation_admin_employees_path, params: {
      national_ids: [ duplicated_national_id, valid_dni(44_000_015), duplicated_national_id ],
      bulk_action: { action: "activate" }
    }

    assert_redirected_to bulk_activation_admin_employees_path
    assert_equal "No s'ha pogut simular la llista. El DNI/NIE #{duplicated_national_id} està duplicat 2 vegades.",
      flash[:alert]
  end
end
