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
    assert_select "form.admin-reports-form[action='#{admin_reports_path}'][method='get'][data-controller='reports'][data-reports-export-url-value='#{admin_report_exports_path}'][data-reports-summary-csv-url-value='#{admin_reports_monthly_summary_path(format: :csv)}']" do
      assert_select ".admin-reports-period-panel" do
        assert_select "select[name='month'][data-reports-target='month'] option[selected][value='#{Time.zone.today.month}']"
        assert_select "select[name='year'][data-reports-target='year'] option[selected][value='#{Time.zone.today.year}']"
      end
      assert_select ".admin-reports-tabs-nav", count: 0
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
    employee = create_employee(first_name: "Clara", last_name: "Pons", national_id: valid_dni(12_345_681))
    obra = Tag.create!(name: "Obra", color: "#0f766e", active: true)
    oficina = Tag.create!(name: "Oficina", color: "#2563eb", active: true)
    employee.tags << [ oficina, obra ]
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 9, 0))
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 17, 0))
    create_employee(first_name: "Aina", last_name: "Sense hores", national_id: valid_dni(12_345_682))

    get admin_reports_monthly_summary_path(format: :csv), params: { month: 7, year: 2026 }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.headers.fetch("Content-Disposition"), "fitxa-cae-resum-mensual-2026-07.csv"

    csv = CSV.parse(response.body, headers: true)
    assert_equal [ "Persona", "DNI/NIE", "Etiquetes", "Fitxatges", "Hores" ], csv.headers
    assert_equal 2, csv.size
    assert_equal "Clara Pons", csv[0]["Persona"]
    assert_equal employee.national_id, csv[0]["DNI/NIE"]
    assert_equal "Obra;Oficina", csv[0]["Etiquetes"]
    assert_equal "2", csv[0]["Fitxatges"]
    assert_equal "8 h 00 min", csv[0]["Hores"]
    assert_equal "Aina Sense hores", csv[1]["Persona"]
    assert_equal "0 h 00 min", csv[1]["Hores"]
  end
end
