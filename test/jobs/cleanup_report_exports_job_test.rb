require "test_helper"

class CleanupReportExportsJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test "marks expired exports and enqueues artifact purge" do
    manager = create_manager
    report_export = manager.report_exports.create!(
      kind: "person_pdf",
      status: :completed,
      progress: 100,
      filename: "informe.pdf",
      content_type: "application/pdf",
      expires_at: 1.minute.ago,
      parameters: { month: 7, year: 2026, employee_id: create_employee.id }
    )
    ActiveStorage::Attachment
      .where(record_type: "ReportExport", record_id: report_export.id)
      .find_each(&:purge)
    report_export.artifact.attach(
      io: StringIO.new("PDF"),
      filename: "informe.pdf",
      content_type: "application/pdf"
    )

    assert_enqueued_jobs 1, only: ActiveStorage::PurgeJob do
      CleanupReportExportsJob.perform_now(Time.current)
    end

    assert_predicate report_export.reload, :expired?
    assert_equal 100, report_export.progress
  end
end
