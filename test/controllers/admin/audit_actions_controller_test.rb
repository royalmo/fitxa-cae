require "test_helper"

class Admin::AuditActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @manager = create_manager(email: "admin.audit@example.test")
    log_in_manager(@manager)
  end

  test "lists audit actions" do
    employee = create_employee(first_name: "Iu", last_name: "Bosch")
    other_employee = create_employee(first_name: "Ona", last_name: "Mas", national_id: valid_dni(12_345_679))
    AuditAction.create!(
      author: @manager,
      recipient: employee,
      kind: "employee.updated",
      extra_info: { "field" => "active" },
      created_at: Time.zone.local(2026, 7, 4, 10, 30)
    )
    AuditAction.create!(
      author: @manager,
      recipient: other_employee,
      kind: "employee.updated",
      created_at: Time.zone.local(2026, 7, 6, 10, 30)
    )
    AuditAction.create!(
      author: other_employee,
      recipient: @manager,
      kind: "employee.updated",
      created_at: Time.zone.local(2026, 7, 5, 10, 30)
    )
    AuditAction.create!(
      author: @manager,
      recipient: other_employee,
      kind: "swipe_correction.approved",
      created_at: Time.zone.local(2026, 6, 4, 10, 30)
    )

    get admin_audit_actions_path, params: {
      author_type: "Manager",
      author: "Manager:#{@manager.id}",
      recipient: "Employee:#{employee.id}",
      kind: "employee.updated",
      month: "7",
      year: "2026"
    }

    assert_response :success
    assert_match "employee.updated", response.body
    assert_match "Iu Bosch", response.body
    assert_no_match "Ona Mas", response.body
    assert_no_match "swipe_correction.approved", response.body
    assert_select "table thead" do
      assert_select "th", text: "Data i hora"
      assert_select "th", text: "Autor/a"
      assert_select "th", text: "Activitat"
      assert_select "th", text: "Accions"
      assert_select "th", text: "Receptor/a", count: 0
      assert_select "th", text: "Detall", count: 0
    end
    assert_select "td.admin-audit-author-cell a.admin-audit-subject-link[href='#{edit_admin_manager_path(@manager)}']" do
      assert_select "svg.admin-audit-author-icon"
      assert_select ".admin-audit-subject-name", text: "Laia Riera"
    end
    assert_select "td", text: "Actualitzada la persona Iu Bosch: estat."
    assert_select "button[data-bs-toggle='modal'][data-bs-target^='#admin_audit_action_modal_'] svg.icon"
    assert_select ".modal[id^='admin_audit_action_modal_']" do
      assert_select "dt", text: "Data i hora"
      assert_select "dt", text: "Autor/a"
      assert_select "dt", text: "Receptor/a"
      assert_select "dd a.admin-audit-subject-link[href='#{edit_admin_employee_path(employee)}']", text: "Iu Bosch"
      assert_select "dd", text: "Actualitzada la persona Iu Bosch: estat."
      assert_select "textarea.admin-audit-action-raw-details[disabled]", text: /"field": "active"/
    end
    assert_select "h2", text: "Filtres", count: 0
    assert_select "form.admin-audit-actions-filter-form[action='#{admin_audit_actions_path}'][method='get'][data-controller='audit-filters']" do
      assert_select ".admin-audit-actions-author-kind-filter[role='group'][aria-label='Tipus d\\'autor']" do
        assert_select "input[type='radio'][name='author_type'][value=''][autocomplete='off'] + label", text: "Tots"
        assert_select "input[type='radio'][name='author_type'][value='Employee'][autocomplete='off'] + label", text: "Persones"
        assert_select "input[type='radio'][name='author_type'][value='Manager'][checked='checked'][autocomplete='off'] + label", text: "Responsables"
      end
      assert_select ".admin-audit-actions-primary-filters .admin-audit-kind-search[data-controller='audit-kind-search'][data-audit-kind-search-url-value='#{admin_audit_kind_search_path}']" do
        assert_select "input[type='hidden'][name='kind'][value='employee.updated'][data-audit-kind-search-target='kind']"
        assert_select "input[name='kind_query'][value='Persona actualitzada'][placeholder='Tipus d\\'acció'][role='combobox']"
        assert_select "button[data-audit-kind-search-target='clearButton'][disabled]", count: 0
        assert_select "#admin-audit-actions-kind-results.admin-audit-kind-search-results[role='listbox']"
      end
      assert_select ".admin-audit-actions-primary-filters select[name='month'][data-action='change->list-loading#filter'] option[selected][value='7']"
      assert_select ".admin-audit-actions-primary-filters select[name='month'] option[value='']", text: "Tots els mesos"
      assert_select ".admin-audit-actions-primary-filters select[name='year'][data-action='change->list-loading#filter'] option[selected][value='2026']"
      assert_select ".admin-audit-actions-primary-filters select[name='year'] option[value='']", text: "Tots els anys"
      assert_select ".admin-audit-actions-subject-filters" do
        assert_select "label[for='author']", text: "Fet per"
        assert_select ".admin-audit-author-search[data-controller='audit-author-search'][data-audit-author-search-url-value='#{admin_audit_author_search_path}'][data-audit-author-search-use-author-type-value='true']" do
          assert_select "input[type='hidden'][name='author'][value='Manager:#{@manager.id}'][data-audit-author-search-target='author'][data-audit-filters-target='author']"
          assert_select "input[name='author_query'][value='Laia Riera'][placeholder='Cerca per nom, DNI, correu o telèfon'][role='combobox'][data-audit-filters-target='authorInput']"
          assert_select "button[data-audit-author-search-target='clearButton'][disabled]", count: 0
          assert_select "#admin-audit-actions-author-results.admin-audit-author-search-results[role='listbox']"
        end
        assert_select "label[for='recipient']", text: "Receptor/a:"
        assert_select ".admin-audit-author-search[data-controller='audit-author-search'][data-audit-author-search-url-value='#{admin_audit_author_search_path}'][data-audit-author-search-use-author-type-value='false']" do
          assert_select "input[type='hidden'][name='recipient'][value='Employee:#{employee.id}'][data-audit-author-search-target='author']"
          assert_select "input[name='recipient_query'][value='Iu Bosch'][placeholder='Cerca per nom, DNI, correu o telèfon'][role='combobox']"
          assert_select "button[data-audit-author-search-target='clearButton'][disabled]", count: 0
          assert_select "#admin-audit-actions-recipient-results.admin-audit-author-search-results[role='listbox']"
        end
      end
      assert_select "button", text: "Filtrar", count: 0
    end
    assert_select ".admin-result-count[data-list-loading-target='results']", text: "Mostrant 1-1 de 1"
    assert_select ".text-center .admin-result-count", text: "Mostrant 1-1 de 1"
    assert_select "button[data-bs-toggle='modal'][data-bs-target='#admin_audit_actions_export_modal']", text: "Exportar"
    assert_select "#admin_audit_actions_export_modal form[action='#{export_admin_audit_actions_path}'][method='get'][data-turbo='false']" do
      assert_select "input[type='hidden'][name='author_type'][value='Manager']"
      assert_select "input[type='hidden'][name='author'][value='Manager:#{@manager.id}']"
      assert_select "input[type='hidden'][name='recipient'][value='Employee:#{employee.id}']"
      assert_select "input[type='hidden'][name='kind'][value='employee.updated']"
      assert_select "input[type='hidden'][name='month'][value='7']"
      assert_select "input[type='hidden'][name='year'][value='2026']"
      assert_select "input[type='range'][name='limit'][min='0'][max='1'][value='1'][data-audit-export-target='limit']"
      assert_select "button[type='submit']", text: "Exportar CSV"
    end
  end

  test "disables activity filter clear buttons without selections" do
    get admin_audit_actions_path

    assert_response :success
    assert_select ".admin-audit-author-search button[data-audit-author-search-target='clearButton'][disabled]", count: 2
    assert_select ".admin-audit-kind-search button[data-audit-kind-search-target='clearButton'][disabled]"
  end

  test "exports audit actions as csv" do
    employee = create_employee(first_name: "Iu", last_name: "Bosch")
    included = AuditAction.create!(
      author: @manager,
      recipient: employee,
      kind: "employee.password_changed",
      extra_info: { "changed_fields" => [ "password" ], "origin" => "profile_page" },
      created_at: Time.zone.local(2026, 7, 4, 10, 30)
    )
    AuditAction.create!(
      author: employee,
      recipient: @manager,
      kind: "swipe_correction.approved",
      created_at: Time.zone.local(2026, 7, 5, 10, 30)
    )

    get export_admin_audit_actions_path, params: { author: "Manager:#{@manager.id}", limit: 1 }

    assert_response :success
    assert_includes response.media_type, "text/csv"
    rows = CSV.parse(response.body, headers: true)
    assert_equal [ "datetime", "author", "recipient", "kind", "pretty_activity", "details" ], rows.headers
    assert_equal 1, rows.length
    assert_equal included.created_at.iso8601, rows.first["datetime"]
    assert_equal "manager:#{@manager.id}", rows.first["author"]
    assert_equal "employee:#{employee.id}", rows.first["recipient"]
    assert_equal "employee.password_changed", rows.first["kind"]
    assert_equal "Canviada la contrasenya de Iu Bosch (pàgina de compte).", rows.first["pretty_activity"]
    assert_equal "{\"changed_fields\":[\"password\"],\"origin\":\"profile_page\"}", rows.first["details"]

    export_audit = AuditAction.find_by!(kind: "audit_actions.exported")
    assert_equal @manager, export_audit.author
    assert_equal @manager, export_audit.recipient
    assert_equal 1, export_audit.extra_info.fetch("exported_count")
    assert_equal 1, export_audit.extra_info.fetch("limit")
    assert_equal "manager:#{@manager.id}", export_audit.extra_info.dig("filters", "author")
  end

  test "searches audit authors across employees and managers" do
    employee = create_employee(first_name: "Iu", last_name: "Bosch", national_id: valid_dni(12_345_680))
    manager = create_manager(first_name: "Mireia", last_name: "Serra", email: "mireia.serra@example.test")

    get admin_audit_author_search_path, params: { q: "mireia" }

    assert_response :success
    assert_select ".admin-audit-author-search-result[data-audit-author-search-id-param='Manager:#{manager.id}']" do
      assert_select "svg.admin-audit-author-search-result-icon"
      assert_select "strong", text: "Mireia Serra"
      assert_select ".text-body-secondary", text: "- mireia.serra@example.test"
    end

    get admin_audit_author_search_path, params: { q: "iu", author_type: "Employee" }

    assert_response :success
    assert_select ".admin-audit-author-search-result[data-audit-author-search-id-param='Employee:#{employee.id}']" do
      assert_select "strong", text: "Iu Bosch"
      assert_select ".text-body-secondary", text: "- #{employee.national_id}"
    end
    assert_select ".admin-audit-author-search-result[data-audit-author-search-id-param^='Manager:']", count: 0
  end

  test "searches audit kinds by label and internal key" do
    get admin_audit_kind_search_path, params: { q: "persona" }

    assert_response :success
    assert_select ".admin-audit-kind-search-result[data-audit-kind-search-id-param='employee.updated']" do
      assert_select "span", text: "Persona actualitzada"
      assert_select "code", count: 0
    end

    get admin_audit_kind_search_path, params: { q: "swipe_correction.approved" }

    assert_response :success
    assert_select ".admin-audit-kind-search-result[data-audit-kind-search-id-param='swipe_correction.approved']" do
      assert_select "span", text: "Correcció aprovada"
      assert_select "code", count: 0
    end
  end

  test "preloads the first audit kinds for blank searches" do
    get admin_audit_kind_search_path, params: { q: "" }

    assert_response :success
    assert_select ".admin-audit-kind-search-result", count: 8
    assert_select ".admin-audit-kind-search-result[data-audit-kind-search-id-param='audit_actions.exported']"
    assert_select ".admin-audit-kind-search-result code", count: 0
  end
end
