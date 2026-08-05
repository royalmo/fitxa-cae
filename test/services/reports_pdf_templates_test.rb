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
    employee = create_employee(first_name: "Aina", last_name: "Martinez")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 1, 8, 0))
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 1, 16, 0))
    report = Reports::MonthlyEmployeeReport.new(employee: employee, month: 7, year: 2026).to_h

    html = ApplicationController.render(
      template: "admin/reports/pdf/employee",
      layout: "pdf",
      assigns: { report: report }
    )

    assert_includes html, "Aina Martinez"
    assert_includes html, "8 h 00 min"
    assert_includes html, "Detall diari"
  end

  test "renders monthly summary pdf html" do
    employee = create_employee(first_name: "Clara", last_name: "Pons")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 2, 9, 0))
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 2, 17, 0))
    report = Reports::MonthlySummaryReport.new(month: 7, year: 2026).to_h

    html = ApplicationController.render(
      template: "admin/reports/pdf/monthly_summary",
      layout: "pdf",
      assigns: { report: report }
    )

    assert_includes html, "Resum mensual"
    assert_includes html, "Clara Pons"
    assert_includes html, "8 h 00 min"
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
