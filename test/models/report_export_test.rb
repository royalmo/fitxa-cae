require "test_helper"

class ReportExportTest < ActiveSupport::TestCase
  test "sets queued defaults and expiration" do
    report_export = create_manager.report_exports.create!(
      kind: "monthly_summary_pdf",
      parameters: { month: 7, year: 2026 }
    )

    assert_predicate report_export, :queued?
    assert_equal 0, report_export.progress
    assert report_export.expires_at > 23.hours.from_now
  end

  test "is downloadable only when completed attached and not expired" do
    report_export = create_manager.report_exports.create!(
      kind: "monthly_summary_pdf",
      status: :completed,
      progress: 100,
      filename: "resum.pdf",
      content_type: "application/pdf",
      parameters: { month: 7, year: 2026 }
    )

    assert_not report_export.downloadable?

    ActiveStorage::Attachment
      .where(record_type: "ReportExport", record_id: report_export.id)
      .find_each(&:purge)
    report_export.artifact.attach(
      io: StringIO.new("PDF"),
      filename: "resum.pdf",
      content_type: "application/pdf"
    )
    assert_predicate report_export, :downloadable?

    report_export.update!(expires_at: 1.second.ago)
    assert_not report_export.downloadable?
  end
end
