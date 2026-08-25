require "test_helper"

class Admin::ReportExportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @manager = create_manager(email: "reports.manager@example.test")
    log_in_manager(@manager)
  end

  test "creates a person pdf export and enqueues generation" do
    employee = create_employee(first_name: "Aina", last_name: "Martinez")

    assert_enqueued_with(job: GenerateReportExportJob) do
      post admin_report_exports_path, params: {
        kind: "person_pdf",
        month: "7",
        year: "2026",
        employee_id: employee.id
      }
    end

    assert_response :accepted
    payload = JSON.parse(response.body)
    report_export = ReportExport.find(payload.fetch("id"))

    assert_equal @manager, report_export.manager
    assert_equal "person_pdf", report_export.kind
    assert_equal({ "month" => 7, "year" => 2026, "employee_id" => employee.id }, report_export.parameters)
    assert_equal "queued", payload.fetch("status")
    assert_equal admin_report_export_path(report_export), payload.fetch("status_url")
    assert_nil payload["download_url"]
  end

  test "rejects invalid export requests" do
    assert_no_enqueued_jobs only: GenerateReportExportJob do
      post admin_report_exports_path, params: {
        kind: "person_pdf",
        month: "7",
        year: "2026"
      }
    end

    assert_response :unprocessable_entity
  end

  test "shows completed export status with download url" do
    report_export = completed_report_export

    get admin_report_export_path(report_export)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "completed", payload.fetch("status")
    assert_equal 100, payload.fetch("progress")
    assert_equal download_admin_report_export_path(report_export), payload.fetch("download_url")
  end

  test "shows generic failed export status without raw technical errors" do
    report_export = @manager.report_exports.create!(
      kind: "monthly_summary_pdf",
      status: :failed,
      progress: 35,
      error_message: "Permission denied",
      parameters: { month: 8, year: 2026 }
    )

    get admin_report_export_path(report_export)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "failed", payload.fetch("status")
    assert_equal 35, payload.fetch("progress")
    assert_equal I18n.t("admin.report_exports.errors.generic"), payload.fetch("message")
  end

  test "downloads completed export artifact" do
    report_export = completed_report_export(filename: "informe.pdf", content_type: "application/pdf", bytes: "%PDF")

    get download_admin_report_export_path(report_export)

    assert_response :success
    assert_equal "%PDF", response.body
    assert_equal "application/pdf", response.media_type
    assert_includes response.headers.fetch("Content-Disposition"), "informe.pdf"
  end

  test "does not expose another manager export" do
    other_manager = create_manager(email: "other.reports@example.test")
    report_export = completed_report_export(manager: other_manager)

    get admin_report_export_path(report_export)

    assert_response :not_found
  end

  private

  def completed_report_export(manager: @manager, filename: "informe.pdf", content_type: "application/pdf", bytes: "PDF")
    report_export = manager.report_exports.create!(
      kind: "person_pdf",
      status: :completed,
      progress: 100,
      filename: filename,
      content_type: content_type,
      parameters: { month: 7, year: 2026, employee_id: create_employee.id }
    )
    ActiveStorage::Attachment
      .where(record_type: "ReportExport", record_id: report_export.id)
      .find_each(&:purge)
    report_export.artifact.attach(
      io: StringIO.new(bytes),
      filename: filename,
      content_type: content_type
    )
    report_export
  end
end
