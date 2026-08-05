require "test_helper"
require "zip"

class GenerateReportExportJobTest < ActiveJob::TestCase
  test "generates a person pdf export artifact" do
    manager = create_manager
    employee = create_employee(first_name: "Aina", last_name: "Martinez")
    employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 1, 8, 0))
    employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 7, 1, 16, 0))
    report_export = manager.report_exports.create!(
      kind: "person_pdf",
      parameters: { month: 7, year: 2026, employee_id: employee.id }
    )
    purge_stale_artifact(report_export)

    with_pdf_renderer_result("%PDF person") do
      GenerateReportExportJob.perform_now(report_export)
    end

    report_export.reload
    assert_predicate report_export, :completed?
    assert_equal 100, report_export.progress
    assert_equal "aina-martinez-2026-07.pdf", report_export.filename
    assert_equal "application/pdf", report_export.content_type
    assert_equal "%PDF person", report_export.artifact.download
  end

  test "generates a tag zip export artifact" do
    manager = create_manager
    tag = Tag.create!(name: "Informes test #{SecureRandom.hex(4)}", color: "#2563eb", active: true)
    ActiveRecord::Base.connection.execute("DELETE FROM employees_tags WHERE tag_id = #{tag.id}")
    create_employee(first_name: "Aina", last_name: "Martinez").tags << tag
    create_employee(first_name: "Clara", last_name: "Pons").tags << tag
    report_export = manager.report_exports.create!(
      kind: "tag_zip",
      parameters: { month: 7, year: 2026, tag_id: tag.id }
    )
    purge_stale_artifact(report_export)

    with_pdf_renderer_result("%PDF employee") do
      GenerateReportExportJob.perform_now(report_export)
    end

    report_export.reload
    assert_predicate report_export, :completed?
    assert_equal "application/zip", report_export.content_type

    zip_entries = []
    Zip::File.open_buffer(artifact_data(report_export)) do |zip|
      zip_entries = zip.map(&:name)
    end
    assert_equal 2, zip_entries.size
    assert_match(/\A001-.*-2026-07\.pdf\z/, zip_entries.first)
    assert_match(/\A002-.*-2026-07\.pdf\z/, zip_entries.second)
  end

  test "marks export failed when generation raises" do
    manager = create_manager
    employee = create_employee
    report_export = manager.report_exports.create!(
      kind: "person_pdf",
      parameters: { month: 7, year: 2026, employee_id: employee.id }
    )
    purge_stale_artifact(report_export)

    with_pdf_renderer_error("Chromium unavailable") do
      assert_raises(RuntimeError) do
        GenerateReportExportJob.perform_now(report_export)
      end
    end

    report_export.reload
    assert_predicate report_export, :failed?
    assert_equal "Chromium unavailable", report_export.error_message
  end

  private

  def with_pdf_renderer_result(result, &block)
    with_pdf_renderer(-> { result }, &block)
  end

  def with_pdf_renderer_error(message, &block)
    with_pdf_renderer(-> { raise message }, &block)
  end

  def with_pdf_renderer(replacement)
    singleton = class << Reports::PdfRenderer
      self
    end
    original_method = Reports::PdfRenderer.method(:render)

    singleton.define_method(:render) { |**_kwargs| replacement.call }
    yield
  ensure
    singleton.define_method(:render, original_method) if original_method
  end

  def purge_stale_artifact(report_export)
    ActiveStorage::Attachment
      .where(record_type: "ReportExport", record_id: report_export.id)
      .find_each(&:purge)
  end

  def artifact_data(report_export)
    data = report_export.artifact.download

    data.rewind if data.respond_to?(:rewind)
    data.respond_to?(:read) ? data.read : data
  end
end
