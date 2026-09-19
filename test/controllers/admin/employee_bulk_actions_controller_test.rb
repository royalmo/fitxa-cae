require "test_helper"

class Admin::EmployeeBulkActionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    clear_performed_jobs
    @manager = create_manager
    log_in_manager(@manager)
  end

  test "renders activation bulk action page" do
    get bulk_activation_admin_employees_path

    assert_response :success
    assert_select "title", text: "Activar i desactivar massivament | FitxaCAE Admin"
    assert_select "h1", text: "Activar i desactivar massivament"
    assert_select "a.btn.border-0[href='#{admin_employees_path}']", text: "Tornar"
    assert_select ".admin-bulk-action[data-controller='bulk-national-ids'][data-bulk-national-ids-simulate-url-value='#{simulate_bulk_activation_admin_employees_path}'][data-bulk-national-ids-run-url-value='#{run_bulk_activation_admin_employees_path}'][data-bulk-national-ids-run-no-affected-label-value='Aquesta acció no afectarà cap persona.']" do
      assert_select "form[action='#{run_bulk_activation_admin_employees_path}'][method='post']" do
        assert_select ".admin-bulk-action-layout" do
          assert_select ".admin-bulk-action-form-card.card.shadow-sm > .card-body.admin-bulk-action-form" do
            assert_select ".admin-bulk-action-options[role='group'] > .admin-bulk-action-label", text: "Acció"
            assert_select "input[type='hidden'][name='bulk_action[selection_mode]'][value='national_ids'][data-bulk-national-ids-target='selectionModeInput']"
            assert_select ".nav.nav-tabs[role='tablist']" do
              assert_select "button.nav-link.active[role='tab'][data-bulk-national-ids-mode-param='national_ids']",
                text: "Per DNI"
              assert_select "button.nav-link[role='tab'][data-bulk-national-ids-mode-param='tags']",
                text: "Per etiqueta"
            end
            assert_select "textarea#admin_bulk_national_ids[name='national_ids_text'][data-bulk-national-ids-target='textarea']"
            assert_select "label[for='admin_bulk_national_ids']",
              text: "Llistat de DNI/NIEs, separat per espai, coma, o un per línia."
            assert_select "[role='tabpanel'][data-bulk-national-ids-mode='tags'][hidden]" do
              assert_select "legend.form-label", text: "Persones que tinguin totes les etiquetes següents"
              assert_select "legend.form-label", text: "I que, a la vegada, no tinguin cap de les etiquetes següents"
              assert_select ".admin-tag-multi-search[data-controller='tag-multi-search']", count: 2
              assert_select "input.admin-tag-multi-search-input[name='bulk_activation_include_tag_query'][placeholder='Cerca etiquetes que han de tenir']"
              assert_select "input.admin-tag-multi-search-input[name='bulk_activation_exclude_tag_query'][placeholder='Cerca etiquetes que no poden tenir']"
              assert_select "input[type='hidden'][name='bulk_action[include_tag_ids][]']"
              assert_select "input[type='hidden'][name='bulk_action[exclude_tag_ids][]']"
            end
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
          assert_select "button[type='button'][data-bulk-national-ids-target='confirmRunButton'][data-action='bulk-national-ids#startRun']",
            text: "Sí, executar"
        end
        assert_select "#adminEmployeeBulkActivationConfirmModalProgress.modal.fade" do
          assert_select ".modal-title", text: "Executant l'acció massiva"
          assert_select ".progress[data-bulk-national-ids-target='runProgress']"
          assert_select ".progress-bar[data-bulk-national-ids-target='runProgressBar']", text: "0%"
          assert_select "[data-bulk-national-ids-target='runStatusMessage']"
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
    assert_select ".admin-bulk-action[data-controller='bulk-tags'][data-bulk-tags-simulate-url-value='#{simulate_bulk_tags_admin_employees_path}'][data-bulk-tags-run-url-value='#{run_bulk_tags_admin_employees_path}']" do
      assert_select "form[action='#{run_bulk_tags_admin_employees_path}'][method='post']" do
        assert_select ".admin-bulk-action-form-card" do
          assert_select "legend.form-label", text: "Etiquetes a afegir"
          assert_select "legend.form-label", text: "Etiquetes a treure"
          assert_select ".admin-tag-multi-search[data-controller='tag-multi-search']", count: 2
          assert_select ".admin-tag-multi-search-selections > .admin-tag-multi-search-selection", count: 0
          assert_select "input.admin-tag-multi-search-input[name='bulk_add_tag_query'][placeholder='Cerca etiquetes per afegir']"
          assert_select "input.admin-tag-multi-search-input[name='bulk_remove_tag_query'][placeholder='Cerca etiquetes per treure']"
          assert_select "textarea#admin_bulk_tag_national_ids[name='national_ids_text'][data-bulk-tags-target='textarea']"
          assert_select ".admin-bulk-action-footer.d-flex.flex-column.align-items-start.gap-3 .form-check.form-switch" do
            assert_select "input[type='checkbox'][role='switch'][name='bulk_tags[include_inactive]'][data-bulk-tags-target='includeInactive']:not([checked]) + label",
              text: "Incloure persones inactives"
          end
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
          assert_select "button[type='button'][data-bulk-tags-target='confirmRunButton'][data-action='bulk-tags#startRun']",
            text: "Sí, executar"
        end
        assert_select "#adminEmployeeBulkTagsConfirmModalProgress.modal.fade" do
          assert_select ".modal-title", text: "Executant l'acció massiva"
          assert_select ".progress[data-bulk-tags-target='runProgress']"
          assert_select ".progress-bar[data-bulk-tags-target='runProgressBar']", text: "0%"
          assert_select "[data-bulk-tags-target='runStatusMessage']"
        end
      end
    end
    assert_select "a[href='#{admin_employees_path}']", text: "Tornar a persones", count: 0
  end

  test "renders corrections bulk action page" do
    get bulk_corrections_admin_employees_path

    assert_response :success
    assert_select "title", text: "Permetre correccions massivament | FitxaCAE Admin"
    assert_select "h1", text: "Permetre correccions massivament"
    assert_select ".admin-bulk-action[data-controller='bulk-national-ids'][data-bulk-national-ids-simulate-url-value='#{simulate_bulk_corrections_admin_employees_path}'][data-bulk-national-ids-run-url-value='#{run_bulk_corrections_admin_employees_path}']" do
      assert_select "form[action='#{run_bulk_corrections_admin_employees_path}'][method='post']" do
        assert_select "textarea#admin_bulk_corrections_national_ids[name='national_ids_text'][data-bulk-national-ids-target='textarea']"
        assert_select "input[type='radio'][name='bulk_action[action]'][value='allow'][autocomplete='off'] + label",
          text: "Permetre"
        assert_select "input[type='radio'][name='bulk_action[action]'][value='disallow'][autocomplete='off'] + label",
          text: "No permetre"
        assert_select "[role='tabpanel'][data-bulk-national-ids-mode='tags'][hidden]" do
          assert_select "legend.form-label", text: "Persones que tinguin totes les etiquetes següents"
          assert_select "legend.form-label", text: "I que, a la vegada, no tinguin cap de les etiquetes següents"
          assert_select "input.admin-tag-multi-search-input[name='bulk_corrections_include_tag_query'][placeholder='Cerca etiquetes que han de tenir']"
          assert_select "input.admin-tag-multi-search-input[name='bulk_corrections_exclude_tag_query'][placeholder='Cerca etiquetes que no poden tenir']"
        end
        assert_select ".admin-bulk-action-footer.d-flex.flex-column.align-items-start.gap-3 .form-check.form-switch" do
          assert_select "input[type='checkbox'][role='switch'][name='bulk_action[include_inactive]'][data-bulk-national-ids-target='includeInactive']:not([checked]) + label",
            text: "Incloure persones inactives"
        end
        assert_select ".admin-bulk-simulation-kpis dt", text: "DNI/NIEs trobats"
        assert_select ".admin-bulk-simulation-kpis dt", text: "Persones amb correccions permeses"
        assert_select "#adminEmployeeBulkCorrectionsConfirmModal.modal.fade" do
          assert_select ".modal-title", text: "Executar acció massiva"
        end
      end
    end
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

  test "simulates correction permission states for national ids" do
    allowed_employee = create_employee(national_id: valid_dni(44_200_001), allow_corrections: true)
    disallowed_employee = create_employee(national_id: valid_dni(44_200_002), allow_corrections: false)
    inactive_employee = create_employee(national_id: valid_dni(44_200_003), active: false, allow_corrections: false)

    post simulate_bulk_corrections_admin_employees_path,
      params: {
        national_ids: [
          allowed_employee.national_id,
          disallowed_employee.national_id,
          inactive_employee.national_id,
          valid_dni(44_200_004)
        ]
      },
      as: :json

    assert_response :success
    assert_equal({
      allowed_employee.national_id => true,
      disallowed_employee.national_id => false
    }, JSON.parse(response.body))
  end

  test "simulates correction permission states including inactive national ids when requested" do
    active_employee = create_employee(national_id: valid_dni(44_200_005), allow_corrections: true)
    inactive_employee = create_employee(national_id: valid_dni(44_200_006), active: false, allow_corrections: false)

    post simulate_bulk_corrections_admin_employees_path,
      params: {
        national_ids: [ active_employee.national_id, inactive_employee.national_id ],
        bulk_action: { include_inactive: "1" }
      },
      as: :json

    assert_response :success
    assert_equal({
      active_employee.national_id => true,
      inactive_employee.national_id => false
    }, JSON.parse(response.body))
  end

  test "simulates activation states for tag selections" do
    included_tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    required_tag = Tag.create!(name: "Morning", color: "#16a34a", active: true)
    excluded_tag = Tag.create!(name: "External", color: "#dc2626", active: true)
    active_employee = create_employee(national_id: valid_dni(44_000_021), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_000_022), active: false)
    missing_required_tag_employee = create_employee(national_id: valid_dni(44_000_023), active: false)
    excluded_employee = create_employee(national_id: valid_dni(44_000_024), active: false)

    active_employee.tags << [ included_tag, required_tag ]
    inactive_employee.tags << [ included_tag, required_tag ]
    missing_required_tag_employee.tags << included_tag
    excluded_employee.tags << [ included_tag, required_tag, excluded_tag ]
    total_employee_count = Employee.count

    post simulate_bulk_activation_admin_employees_path,
      params: {
        bulk_action: {
          selection_mode: "tags",
          include_tag_ids: [ included_tag.id, required_tag.id ],
          exclude_tag_ids: [ excluded_tag.id ]
        }
      },
      as: :json

    assert_response :success
    assert_equal({
      "total_count" => total_employee_count,
      "found_count" => 2,
      "active_count" => 1,
      "inactive_count" => 1
    }, JSON.parse(response.body))
  end

  test "simulates correction permission states for active tag selections by default" do
    included_tag = Tag.create!(name: "Correccions", color: "#2563eb", active: true)
    allowed_employee = create_employee(national_id: valid_dni(44_200_007), allow_corrections: true)
    disallowed_employee = create_employee(national_id: valid_dni(44_200_008), allow_corrections: false)
    inactive_employee = create_employee(national_id: valid_dni(44_200_009), active: false, allow_corrections: false)
    allowed_employee.tags << included_tag
    disallowed_employee.tags << included_tag
    inactive_employee.tags << included_tag

    post simulate_bulk_corrections_admin_employees_path,
      params: {
        bulk_action: {
          selection_mode: "tags",
          include_tag_ids: [ included_tag.id ],
          include_inactive: "0"
        }
      },
      as: :json

    assert_response :success
    assert_equal({
      "total_count" => Employee.active.count,
      "found_count" => 2,
      "active_count" => 1,
      "inactive_count" => 1
    }, JSON.parse(response.body))
  end

  test "simulates correction permission states including inactive tag selections when requested" do
    included_tag = Tag.create!(name: "Correccions extra", color: "#2563eb", active: true)
    allowed_employee = create_employee(national_id: valid_dni(44_200_010), allow_corrections: true)
    disallowed_employee = create_employee(national_id: valid_dni(44_200_011), allow_corrections: false)
    inactive_employee = create_employee(national_id: valid_dni(44_200_012), active: false, allow_corrections: false)
    allowed_employee.tags << included_tag
    disallowed_employee.tags << included_tag
    inactive_employee.tags << included_tag

    post simulate_bulk_corrections_admin_employees_path,
      params: {
        bulk_action: {
          selection_mode: "tags",
          include_tag_ids: [ included_tag.id ],
          include_inactive: "1"
        }
      },
      as: :json

    assert_response :success
    assert_equal({
      "total_count" => Employee.count,
      "found_count" => 3,
      "active_count" => 1,
      "inactive_count" => 2
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

  test "enqueues bulk tag changes for active employees by default" do
    add_tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    remove_tag = Tag.create!(name: "Warehouse", color: "#16a34a", active: true)
    active_employee = create_employee(national_id: valid_dni(44_100_007), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_100_008), active: false)
    active_employee.tags << remove_tag
    inactive_employee.tags << remove_tag

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post run_bulk_tags_admin_employees_path,
        params: {
          national_ids: [ active_employee.national_id, inactive_employee.national_id ],
          bulk_tags: { add_tag_ids: [ add_tag.id ], remove_tag_ids: [ remove_tag.id ], include_inactive: "0" }
        },
        as: :json
    end

    assert_response :accepted
    payload = JSON.parse(response.body)
    employee_bulk_action_run = EmployeeBulkActionRun.find(payload.fetch("id"))
    assert_equal @manager, employee_bulk_action_run.manager
    assert_equal "tags", employee_bulk_action_run.kind
    assert_equal "queued", payload.fetch("status")
    assert_equal admin_employee_bulk_action_run_path(employee_bulk_action_run), payload.fetch("status_url")
    assert_not_includes active_employee.reload.tags, add_tag
    assert_includes active_employee.tags, remove_tag

    perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)

    assert_includes active_employee.reload.tags, add_tag
    assert_not_includes active_employee.tags, remove_tag
    assert_not_includes inactive_employee.reload.tags, add_tag
    assert_includes inactive_employee.tags, remove_tag
    assert_equal "S'han actualitzat les etiquetes d'1 persona.", employee_bulk_action_run.reload.result_message
  end

  test "rejects bulk tag changes with no affected employees" do
    tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    employee = create_employee(national_id: valid_dni(44_100_009), active: true)
    employee.tags << tag

    assert_no_enqueued_jobs only: ProcessEmployeeBulkActionRunJob do
      post run_bulk_tags_admin_employees_path,
        params: {
          national_ids: [ employee.national_id ],
          bulk_tags: { add_tag_ids: [ tag.id ] }
        },
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "Aquesta acció no afectarà cap persona.", JSON.parse(response.body).fetch("error")
  end

  test "enqueues activation bulk action" do
    active_employee = create_employee(national_id: valid_dni(44_000_004), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_000_005), active: false)

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post run_bulk_activation_admin_employees_path,
        params: {
          national_ids: [ active_employee.national_id, inactive_employee.national_id, valid_dni(44_000_006) ],
          bulk_action: { action: "activate" }
        },
        as: :json
    end

    assert_response :accepted
    payload = JSON.parse(response.body)
    employee_bulk_action_run = EmployeeBulkActionRun.find(payload.fetch("id"))
    assert_equal @manager, employee_bulk_action_run.manager
    assert_equal "activation", employee_bulk_action_run.kind
    assert_equal "queued", payload.fetch("status")
    assert_equal admin_employee_bulk_action_run_path(employee_bulk_action_run), payload.fetch("status_url")
    assert_not inactive_employee.reload.active?

    perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)

    assert_predicate active_employee.reload, :active?
    assert_predicate inactive_employee.reload, :active?
    assert_predicate inactive_employee.current_employment_period, :open?
    assert_equal "S'ha activat 1 persona.", employee_bulk_action_run.reload.result_message
  end

  test "enqueues activation bulk action for tag selections" do
    included_tag = Tag.create!(name: "Office", color: "#2563eb", active: true)
    excluded_tag = Tag.create!(name: "External", color: "#dc2626", active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_000_025), active: false)
    active_employee = create_employee(national_id: valid_dni(44_000_026), active: true)
    excluded_employee = create_employee(national_id: valid_dni(44_000_027), active: false)
    inactive_employee.tags << included_tag
    active_employee.tags << included_tag
    excluded_employee.tags << [ included_tag, excluded_tag ]

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post run_bulk_activation_admin_employees_path,
        params: {
          bulk_action: {
            action: "activate",
            selection_mode: "tags",
            include_tag_ids: [ included_tag.id ],
            exclude_tag_ids: [ excluded_tag.id ]
          }
        },
        as: :json
    end

    assert_response :accepted
    payload = JSON.parse(response.body)
    employee_bulk_action_run = EmployeeBulkActionRun.find(payload.fetch("id"))
    assert_equal @manager, employee_bulk_action_run.manager
    assert_equal "activation", employee_bulk_action_run.kind
    assert_equal "tags", employee_bulk_action_run.parameters.fetch("selection_mode")
    assert_equal [ included_tag.id ], employee_bulk_action_run.parameters.fetch("include_tag_ids")
    assert_equal [ excluded_tag.id ], employee_bulk_action_run.parameters.fetch("exclude_tag_ids")

    perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)

    assert_predicate inactive_employee.reload, :active?
    assert_predicate active_employee.reload, :active?
    assert_not excluded_employee.reload.active?
    assert_equal "S'ha activat 1 persona.", employee_bulk_action_run.reload.result_message
  end

  test "enqueues correction permission bulk action for tag selections" do
    included_tag = Tag.create!(name: "Correccions oficina", color: "#2563eb", active: true)
    excluded_tag = Tag.create!(name: "Sense correccions", color: "#dc2626", active: true)
    disallowed_employee = create_employee(national_id: valid_dni(44_200_004), allow_corrections: false)
    allowed_employee = create_employee(national_id: valid_dni(44_200_005), allow_corrections: true)
    excluded_employee = create_employee(national_id: valid_dni(44_200_006), allow_corrections: false)
    inactive_employee = create_employee(national_id: valid_dni(44_200_013), active: false, allow_corrections: false)
    disallowed_employee.tags << included_tag
    allowed_employee.tags << included_tag
    excluded_employee.tags << [ included_tag, excluded_tag ]
    inactive_employee.tags << included_tag

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post run_bulk_corrections_admin_employees_path,
        params: {
          bulk_action: {
            action: "allow",
            selection_mode: "tags",
            include_tag_ids: [ included_tag.id ],
            exclude_tag_ids: [ excluded_tag.id ],
            include_inactive: "0"
          }
        },
        as: :json
    end

    assert_response :accepted
    payload = JSON.parse(response.body)
    employee_bulk_action_run = EmployeeBulkActionRun.find(payload.fetch("id"))
    assert_equal @manager, employee_bulk_action_run.manager
    assert_equal "corrections", employee_bulk_action_run.kind
    assert_equal "tags", employee_bulk_action_run.parameters.fetch("selection_mode")
    assert_equal false, employee_bulk_action_run.parameters.fetch("include_inactive")

    perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)

    assert_predicate disallowed_employee.reload, :allow_corrections?
    assert_predicate allowed_employee.reload, :allow_corrections?
    assert_not excluded_employee.reload.allow_corrections?
    assert_not inactive_employee.reload.allow_corrections?
    assert_equal "S'han permès les correccions a 1 persona.", employee_bulk_action_run.reload.result_message
  end

  test "enqueues correction permission bulk action including inactive tag selections when requested" do
    included_tag = Tag.create!(name: "Correccions inactives", color: "#2563eb", active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_200_014), active: false, allow_corrections: false)
    inactive_employee.tags << included_tag

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post run_bulk_corrections_admin_employees_path,
        params: {
          bulk_action: {
            action: "allow",
            selection_mode: "tags",
            include_tag_ids: [ included_tag.id ],
            include_inactive: "1"
          }
        },
        as: :json
    end

    assert_response :accepted
    employee_bulk_action_run = EmployeeBulkActionRun.find(JSON.parse(response.body).fetch("id"))
    assert_equal true, employee_bulk_action_run.parameters.fetch("include_inactive")

    perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)

    assert_predicate inactive_employee.reload, :allow_corrections?
    assert_equal "S'han permès les correccions a 1 persona.", employee_bulk_action_run.reload.result_message
  end

  test "enqueues deactivation bulk action" do
    active_employee = create_employee(national_id: valid_dni(44_000_007), active: true)
    inactive_employee = create_employee(national_id: valid_dni(44_000_008), active: false)
    active_employee.current_employment_period.update!(started_at: 2.days.ago)

    assert_enqueued_with(job: ProcessEmployeeBulkActionRunJob) do
      post run_bulk_activation_admin_employees_path,
        params: {
          national_ids: [ active_employee.national_id, inactive_employee.national_id ],
          bulk_action: { action: "deactivate" }
        },
        as: :json
    end

    assert_response :accepted

    perform_enqueued_jobs(only: ProcessEmployeeBulkActionRunJob)

    employee_bulk_action_run = EmployeeBulkActionRun.order(:created_at).last
    assert_not active_employee.reload.active?
    assert_not inactive_employee.reload.active?
    assert_nil active_employee.current_employment_period
    assert_not_nil active_employee.employment_periods.sole.ended_at
    assert_equal "S'ha desactivat 1 persona.", employee_bulk_action_run.result_message
  end

  test "rejects activation bulk actions with no affected employees" do
    employee = create_employee(national_id: valid_dni(44_000_016), active: true)

    assert_no_enqueued_jobs only: ProcessEmployeeBulkActionRunJob do
      post run_bulk_activation_admin_employees_path,
        params: {
          national_ids: [ employee.national_id ],
          bulk_action: { action: "activate" }
        },
        as: :json
    end

    assert_response :unprocessable_entity
    assert_predicate employee.reload, :active?
    assert_equal "Aquesta acció no afectarà cap persona.", JSON.parse(response.body).fetch("error")
  end

  test "rejects invalid activation bulk action requests" do
    employee = create_employee(national_id: valid_dni(44_000_009), active: true)

    post run_bulk_activation_admin_employees_path,
      params: {
        national_ids: [ employee.national_id ],
        bulk_action: { action: "" }
      },
      as: :json

    assert_response :unprocessable_entity
    assert_predicate employee.reload, :active?
    assert_equal "Revisa la llista de DNI/NIE i l'acció seleccionada.", JSON.parse(response.body).fetch("error")
  end

  test "rejects activation bulk actions with the first invalid national id" do
    post run_bulk_activation_admin_employees_path,
      params: {
        national_ids: [ valid_dni(44_000_011), "bad" ],
        bulk_action: { action: "activate" }
      },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "No s'ha pogut simular la llista. Primer DNI/NIE no vàlid: BAD.",
      JSON.parse(response.body).fetch("error")
  end

  test "rejects activation bulk actions with the first duplicated national id" do
    duplicated_national_id = valid_dni(44_000_014)

    post run_bulk_activation_admin_employees_path,
      params: {
        national_ids: [ duplicated_national_id, valid_dni(44_000_015), duplicated_national_id ],
        bulk_action: { action: "activate" }
      },
      as: :json

    assert_response :unprocessable_entity
    assert_equal "No s'ha pogut simular la llista. El DNI/NIE #{duplicated_national_id} està duplicat 2 vegades.",
      JSON.parse(response.body).fetch("error")
  end
end
