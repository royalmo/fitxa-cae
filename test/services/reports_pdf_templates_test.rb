require "test_helper"

class ReportsPdfTemplatesTest < ActiveSupport::TestCase
  test "pdf renderer passes ferrum compatible options" do
    employee = create_employee(first_name: "Aina", last_name: "Martinez")
    report = Reports::MonthlyEmployeeReport.new(employee: employee, month: 7, year: 2026).to_h
    captured_args = nil

    with_ferrum_pdf_renderer(->(**args) {
      captured_args = args
      "%PDF rendered"
    }) do
      result = Reports::PdfRenderer.render(template: "admin/reports/pdf/employee", assigns: { report: report })

      assert_equal "%PDF rendered", result
    end

    assert_includes captured_args.fetch(:html), "Aina Martinez"
    assert_equal "http://fitxa-cae.local/", captured_args.fetch(:display_url)
    assert_equal :A4, captured_args.fetch(:pdf_options).fetch(:format)
    assert_equal true, captured_args.fetch(:pdf_options).fetch(:print_background)
  end

  test "renders employee pdf html" do
    manager = create_manager(first_name: "Marta", last_name: "Serra")
    employee = create_employee(
      first_name: "Aina",
      last_name: "Martinez",
      email: "aina@example.test",
      phone: "600 111 222"
    )
    tag = Tag.create!(name: "Obra", color: "#0f766e", active: true)
    employee.tags << tag
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 1, 8, 0))
    invalidated_swipe = employee.swipes.create!(
      kind: :exit,
      swipe_at: Time.zone.local(2026, 7, 1, 15, 0),
      removed: true
    )
    correction = employee.swipe_corrections.create!(
      requester: employee,
      status: :approved,
      day: Date.new(2026, 7, 1),
      details: {
        "invalidated_swipe_ids" => [ invalidated_swipe.id ],
        "requested_swipes" => [ { "kind" => "exit", "hour" => "16:00:00" } ]
      }
    )
    employee.swipes.create!(
      kind: :exit,
      swipe_at: Time.zone.local(2026, 7, 1, 16, 0),
      forged: true,
      metadata: "admin_correction:#{correction.id}"
    )
    report = Reports::MonthlyEmployeeReport.new(employee: employee, month: 7, year: 2026).to_h
    generated_at = Time.zone.local(2026, 8, 5, 14, 30)

    html = travel_to generated_at do
      ApplicationController.render(
        template: "admin/reports/pdf/employee",
        layout: "pdf",
        assigns: {
          report: report,
          report_generated_by: manager,
          report_generated_at: generated_at
        }
      )
    end

    assert_includes html, "Aina Martinez"
    assert_includes html, "Fitxatges - Juliol de 2026"
    assert_includes html, "600 111 222"
    assert_includes html, "Obra"
    assert_includes html, "report-employee-tags"
    assert_includes html, "8 h 00 min"
    refute_includes html, "Detall diari"
    refute_includes html, "Etiquetes"
    refute_includes html, "Correccions del mes"
    refute_includes html, "<th class=\"report-text-end\">Correccions</th>"
    refute_includes html, "Sense fitxatges"
    assert_includes html, "report-empty-day"
    assert_includes html, "---"
    assert_includes html, "report-swipe-deleted"
    assert_includes html, "report-swipe-time"
    assert_includes html, "report-swipe-deleted-time"
    assert_includes html, "report-swipe-corrected"
    assert_includes html, "Informe generat per Marta Serra"
    assert_includes html, "el dia #{I18n.l(generated_at.to_date, format: :long)}"
    assert_includes html, "a les 14:30."
    assert_includes html, "Entrada"
    assert_includes html, "Sortida"
    assert_includes html, "Corregida"
    assert_includes html, "Eliminada"
  end

  test "renders monthly summary pdf html" do
    employee = nil

    travel_to Time.zone.local(2026, 7, 1, 8, 0) do
      employee = create_employee(first_name: "Clara", last_name: "Pons")
      create_employee(first_name: "Aina", last_name: "Sense hores", national_id: valid_dni(12_345_679))
    end

    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 9, 0))
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 17, 0))
    report = Reports::MonthlySummaryReport.new(month: 7, year: 2026).to_h

    html = ApplicationController.render(
      template: "admin/reports/pdf/monthly_summary",
      layout: "pdf",
      assigns: { report: report }
    )

    assert_includes html, "Resum mensual - Juliol de 2026"
    assert_includes html, "Recompte d'hores per cada persona activa o amb fitxatges en aquest mes."
    refute_includes html, "class=\"report-kpis\""
    refute_includes html, "<h2>Persones</h2>"
    assert_includes html, "Clara Pons"
    assert_includes html, "8 h 00 min"
    assert_includes html, "report-duration-zero"
    assert_includes html, "0 h 00 min"
  end

  private

  def with_ferrum_pdf_renderer(replacement)
    singleton = class << FerrumPdf
      self
    end
    original_method = FerrumPdf.method(:render_pdf)

    singleton.define_method(:render_pdf) { |**kwargs| replacement.call(**kwargs) }
    yield
  ensure
    singleton.define_method(:render_pdf, original_method) if original_method
  end
end
