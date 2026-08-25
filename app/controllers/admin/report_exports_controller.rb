class Admin::ReportExportsController < Admin::BaseController
  def create
    report_export = current_manager.report_exports.create!(
      kind: selected_kind,
      parameters: export_parameters
    )
    GenerateReportExportJob.perform_later(report_export)

    render json: report_export_payload(report_export), status: :accepted
  rescue ActiveRecord::RecordInvalid, ActionController::BadRequest => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def show
    report_export = current_manager.report_exports.find(params[:id])
    expire_report_export(report_export)

    render json: report_export_payload(report_export)
  end

  def download
    report_export = current_manager.report_exports.find(params[:id])
    expire_report_export(report_export)

    unless report_export.downloadable?
      redirect_to admin_reports_path, alert: t("admin.report_exports.unavailable")
      return
    end

    record_audit_action!(
      author: current_manager,
      recipient: current_manager,
      kind: "report_export.downloaded",
      extra_info: audit_report_export_details(report_export)
    )

    send_data artifact_data(report_export),
      filename: report_export.filename,
      type: report_export.content_type,
      disposition: :attachment
  end

  private

  def selected_kind
    kind = params[:kind].to_s
    raise ActionController::BadRequest, t("admin.report_exports.errors.invalid_kind") unless kind.in?(ReportExport::KINDS)

    kind
  end

  def export_parameters
    parameters = {
      month: selected_month,
      year: selected_year
    }

    case selected_kind
    when "person_pdf"
      parameters[:employee_id] = selected_employee.id
    when "tag_zip"
      parameters[:tag_id] = selected_tag.id
    end

    parameters
  end

  def selected_month
    month = Integer(params[:month], exception: false)
    raise ActionController::BadRequest, t("admin.report_exports.errors.invalid_period") unless month&.between?(1, 12)

    month
  end

  def selected_year
    year = Integer(params[:year], exception: false)
    raise ActionController::BadRequest, t("admin.report_exports.errors.invalid_period") unless year&.between?(2000, 2100)

    year
  end

  def selected_employee
    employee = Employee.find_by(id: params[:employee_id].presence)
    raise ActionController::BadRequest, t("admin.report_exports.errors.missing_employee") unless employee

    employee
  end

  def selected_tag
    tag = Tag.active.find_by(id: params[:tag_id].presence)
    raise ActionController::BadRequest, t("admin.report_exports.errors.missing_tag") unless tag

    tag
  end

  def report_export_payload(report_export)
    {
      id: report_export.id,
      status: report_export.status,
      progress: report_export.progress,
      message: report_export_message(report_export),
      filename: report_export.filename,
      status_url: admin_report_export_path(report_export),
      download_url: (download_admin_report_export_path(report_export) if report_export.downloadable?)
    }.compact
  end

  def report_export_message(report_export)
    return t("admin.report_exports.errors.generic") if report_export.failed?
    return t("admin.report_exports.statuses.expired") if report_export.expired?

    t("admin.report_exports.statuses.#{report_export.status}")
  end

  def expire_report_export(report_export)
    report_export.mark_expired! if report_export.past_expiration? && !report_export.expired?
  end

  def artifact_data(report_export)
    data = report_export.artifact.download

    data.rewind if data.respond_to?(:rewind)
    data.respond_to?(:read) ? data.read : data
  end
end
