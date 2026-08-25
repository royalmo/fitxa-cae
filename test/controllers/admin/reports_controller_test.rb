require "test_helper"
require "csv"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_manager
  end

  test "renders report download workspace" do
    get admin_reports_path

    assert_response :success
    assert_select "h1", text: "Informes"
    assert_no_match "Pàgina pendent.", response.body
    assert_select "form.admin-reports-form[action='#{admin_reports_path}'][method='get'][data-controller='reports'][data-reports-export-url-value='#{admin_report_exports_path}'][data-reports-summary-csv-url-value='#{admin_reports_monthly_summary_path(format: :csv)}'][data-reports-period-problems-url-value='#{admin_reports_period_problems_path}']" do
      assert_select ".admin-reports-period-panel" do
        assert_select "select[name='month'][data-reports-target='month'] option[selected][value='#{Time.zone.today.month}']"
        assert_select "select[name='year'][data-reports-target='year'] option[selected][value='#{Time.zone.today.year}']"
        assert_select "[data-reports-target='periodProblem']" do
          assert_select ".admin-reports-period-problem.is-clear", text: "No hi ha correccions pendents."
        end
      end
      assert_select ".admin-reports-tabs-nav", count: 0
      form = css_select("form.admin-reports-form").first
      assert_equal I18n.t("admin.reports.index.export_start_error"), form["data-reports-start-error-label-value"]
      assert_equal I18n.t("admin.reports.index.export_poll_error"), form["data-reports-poll-error-label-value"]
      assert_equal I18n.t("admin.reports.index.period_problems.loading"), form["data-reports-period-problem-loading-label-value"]
      assert_select ".admin-report-card", count: 2
      assert_select ".admin-report-card", text: /Resum per persona/ do
        assert_select "h2", text: "Resum per persona"
        assert_select "input[type='radio'][name='report_scope'][value='person'][checked='checked'][data-reports-target='scope']"
        assert_select "input[type='radio'][name='report_scope'][value='tag'][data-reports-target='scope']"
        assert_select "input[type='radio'][name='report_scope'][value='company'][data-reports-target='scope']"
        assert_select "label[for='admin_report_scope_company']", text: "Tota l'empresa"
        assert_select "[data-reports-target='employeeField']" do
          assert_select "[data-controller='employee-search'][data-employee-search-auto-submit-value='false']"
          assert_select "input[name='employee_query'][data-reports-target='employeeQuery']"
        end
        assert_select "[data-reports-target='tagField'][hidden]"
        assert_select "[data-controller='employee-search'][data-employee-search-auto-submit-value='false']"
        assert_select "button[data-reports-target='personButton'][data-action='reports#startPersonReport'][disabled]", text: "Descarregar PDF"
      end
      assert_select ".admin-report-card", text: /Resum mensual/ do
        assert_select "h2", text: "Resum mensual"
        assert_select "table.admin-report-summary-preview", count: 0
        assert_match "persones actives", response.body
        assert_match "hores treballades", response.body
        assert_select "button[data-reports-target='summaryButton'][disabled]", count: 0
        assert_select "button[data-reports-target='summaryButton'][data-action='reports#startSummaryReport']", text: "Descarregar PDF"
        assert_select "a[data-reports-target='summaryCsvLink'][data-turbo='false'][href='#{admin_reports_monthly_summary_path(format: :csv, month: Time.zone.today.month, year: Time.zone.today.year)}']", text: "Descarregar CSV"
      end
      assert_select "#adminReportExportModal[data-reports-target='modal']" do
        assert_select "[data-reports-target='progress']"
        assert_select "[data-reports-target='progressBar']"
        assert_select "[data-reports-target='statusMessage']"
        assert_select "a[data-reports-target='downloadLink'][href]", 0
      end
    end
    assert_select "[data-controller='list-loading']", 0
    assert_select "input[type='month']", 0
    assert_select "a[href='#']", 0
  end

  test "renders erroneous swipes period problem before pending corrections" do
    odd_employee = create_employee(first_name: "Jana", last_name: "Imparell", national_id: valid_dni(42_600_001))
    pending_employee = create_employee(first_name: "Berta", last_name: "Pendent", national_id: valid_dni(42_600_002))
    odd_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 15, 9, 0))
    pending_employee.swipe_corrections.create!(
      requester: pending_employee,
      status: :pending,
      day: Date.new(2026, 8, 16)
    )

    travel_to Time.zone.local(2026, 8, 25, 12, 0) do
      get admin_reports_path, params: { month: "8", year: "2026" }
    end

    assert_response :success
    assert_select ".admin-reports-period-problem", text: /Hi ha fitxatges erronis en aquest mes/
    assert_select ".admin-reports-period-problem .admin-reports-period-problem-icon", count: 0
    assert_select ".admin-reports-period-problem a.btn.admin-reports-period-problem-action[href='#{admin_swipes_path(search_mode: "category", category: "erroneous_swipes", month: 8, year: 2026)}']", text: "Veure"
    assert_no_match "Hi ha correccions pendents en aquest mes", response.body
  end

  test "renders pending corrections period problem when there are no erroneous swipes" do
    employee = create_employee(first_name: "Berta", last_name: "Pendent", national_id: valid_dni(42_600_003))
    employee.swipe_corrections.create!(
      requester: employee,
      status: :pending,
      day: Date.new(2026, 7, 16)
    )

    get admin_reports_path, params: { month: "7", year: "2026" }

    assert_response :success
    assert_select ".admin-reports-period-problem", text: /Hi ha correccions pendents en aquest mes/
    assert_select ".admin-reports-period-problem a.btn[href='#{admin_corrections_path(status: "pending", month: 7, year: 2026)}']", text: "Veure"
  end

  test "returns period problem html as json" do
    employee = create_employee(first_name: "Jana", last_name: "Imparell", national_id: valid_dni(42_600_004))
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 15, 9, 0))

    travel_to Time.zone.local(2026, 8, 25, 12, 0) do
      get admin_reports_period_problems_path, params: { month: "8", year: "2026" }, as: :json
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_includes payload.fetch("html"), "Hi ha fitxatges erronis en aquest mes"
    assert_includes payload.fetch("html"), ERB::Util.html_escape(admin_swipes_path(search_mode: "category", category: "erroneous_swipes", month: 8, year: 2026))

    get admin_reports_period_problems_path, params: { month: "6", year: "2026" }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_includes payload.fetch("html"), "No hi ha correccions pendents."
    assert_includes payload.fetch("html"), "is-clear"
  end

  test "keeps selected report filters from params" do
    employee = create_employee(first_name: "Iu", last_name: "Bosch")
    tag = Tag.create!(name: "Oficina", color: "#2563eb", active: true)

    get admin_reports_path, params: {
      month: "4",
      year: "2025",
      employee_id: employee.id,
      tag_id: tag.id
    }

    assert_response :success
    assert_select "select[name='month'] option[selected][value='4']"
    assert_select "select[name='year'] option[selected][value='2025']"
    assert_select "input[type='radio'][name='report_scope'][value='person'][checked='checked']"
    assert_select "input[type='hidden'][name='employee_id'][value='#{employee.id}']"
    assert_select "input[name='employee_query'][value='Iu Bosch']"
    assert_select "input[type='hidden'][name='tag_id'][value='#{tag.id}']"
    assert_select "input[name='tag_query'][value='Oficina']"
    assert_select "button[data-reports-target='personButton'][disabled]", count: 0
  end

  test "infers tag report scope from tag param" do
    tag = Tag.create!(name: "Obra", color: "#0f766e", active: true)

    get admin_reports_path, params: {
      month: "6",
      year: "2026",
      tag_id: tag.id
    }

    assert_response :success
    assert_select "select[name='month'] option[selected][value='6']"
    assert_select "select[name='year'] option[selected][value='2026']"
    assert_select "input[type='radio'][name='report_scope'][value='tag'][checked='checked']"
    assert_select "[data-reports-target='employeeField'][hidden]"
    assert_select "[data-reports-target='tagField']" do
      assert_select "input[type='hidden'][name='tag_id'][value='#{tag.id}'][data-reports-target='tagId']"
      assert_select "input[name='tag_query'][value='Obra']"
    end
    assert_select "button[data-reports-target='personButton'][disabled]", count: 0, text: "Descarregar ZIP"
  end

  test "shows tag selector for tag report scope" do
    tag = Tag.create!(name: "Oficina", color: "#2563eb", active: true)

    get admin_reports_path, params: { report_scope: "tag", tag_id: tag.id }

    assert_response :success
    assert_select "input[type='radio'][name='report_scope'][value='tag'][checked='checked']"
    assert_select "[data-reports-target='employeeField'][hidden]"
    assert_select "[data-reports-target='tagField']" do
      assert_select "[data-controller='tag-search'][data-tag-search-auto-submit-value='false']"
      assert_select "input[type='hidden'][name='tag_id'][value='#{tag.id}'][data-reports-target='tagId']"
      assert_select "input[name='tag_query'][data-reports-target='tagQuery']"
    end
    assert_select "button[data-reports-target='personButton'][disabled]", count: 0, text: "Descarregar ZIP"
  end

  test "enables person summary for company report scope" do
    get admin_reports_path, params: { report_scope: "company" }

    assert_response :success
    assert_select "input[type='radio'][name='report_scope'][value='company'][checked='checked']"
    assert_select "[data-reports-target='employeeField'][hidden]"
    assert_select "[data-reports-target='tagField'][hidden]"
    assert_select "button[data-reports-target='personButton'][disabled]", count: 0, text: "Descarregar ZIP"
  end

  test "downloads monthly summary csv" do
    employee = nil
    empty_employee = nil
    pending_correction_employee = nil
    odd_swipes_employee = nil
    obra = Tag.create!(name: "Obra", color: "#0f766e", active: true)
    oficina = Tag.create!(name: "Oficina", color: "#2563eb", active: true)

    travel_to Time.zone.local(2026, 7, 1, 8, 0) do
      employee = create_employee(first_name: "Clara", last_name: "Pons", national_id: valid_dni(12_345_681))
      empty_employee = create_employee(first_name: "Aina", last_name: "Sense hores", national_id: valid_dni(12_345_682))
      pending_correction_employee = create_employee(first_name: "Berta", last_name: "Pendent", national_id: valid_dni(12_345_683))
      odd_swipes_employee = create_employee(first_name: "Jana", last_name: "Fitxatge imparell", national_id: valid_dni(12_345_684))
    end

    employee.tags << [ oficina, obra ]
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 9, 0))
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 17, 0))
    pending_correction_employee.swipe_corrections.create!(
      requester: pending_correction_employee,
      status: :pending,
      day: Date.new(2026, 7, 4)
    )
    odd_swipes_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 5, 9, 0))

    get admin_reports_monthly_summary_path(format: :csv), params: { month: 7, year: 2026 }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.headers.fetch("Content-Disposition"), "fitxa-cae-resum-mensual-2026-07.csv"

    csv = CSV.parse(response.body, headers: true)
    headers = I18n.t("admin.reports.csv.monthly_summary.headers")
    assert_equal headers, csv.headers
    assert_equal 4, csv.size
    person_header, national_id_header, tags_header, swipes_header, hours_header, notes_header = headers
    rows_by_person = csv.index_by { |row| row[person_header] }

    clara_row = rows_by_person.fetch("Clara Pons")
    assert_equal employee.national_id, clara_row[national_id_header]
    assert_equal "Obra;Oficina", clara_row[tags_header]
    assert_equal "2", clara_row[swipes_header]
    assert_equal "8 h 00 min", clara_row[hours_header]
    assert_nil clara_row[notes_header]

    empty_row = rows_by_person.fetch("Aina Sense Hores")
    assert_equal empty_employee.national_id, empty_row[national_id_header]
    assert_equal "0 h 00 min", empty_row[hours_header]
    assert_equal I18n.t("admin.reports.csv.monthly_summary.notes.no_swipes"), empty_row[notes_header]

    pending_row = rows_by_person.fetch("Berta Pendent")
    assert_equal I18n.t("admin.reports.csv.monthly_summary.notes.pending_corrections"), pending_row[notes_header]

    odd_swipes_row = rows_by_person.fetch("Jana Fitxatge Imparell")
    assert_equal I18n.t("admin.reports.csv.monthly_summary.notes.erroneous_swipes"), odd_swipes_row[notes_header]
  end
end
