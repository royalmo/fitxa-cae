require "tempfile"
require "zip"

module Reports
  class ExportGenerator
    PDF_CONTENT_TYPE = "application/pdf"
    ZIP_CONTENT_TYPE = "application/zip"

    def initialize(report_export)
      @report_export = report_export
      @parameters = report_export.parameters.symbolize_keys
      @period_start = Date.new(@parameters.fetch(:year).to_i, @parameters.fetch(:month).to_i, 1)
      @generated_at = Time.current
    end

    def generate!
      report_export.mark_running!(progress: 8)

      case report_export.kind
      when "person_pdf"
        generate_person_pdf
      when "tag_zip"
        generate_tag_zip
      when "company_zip"
        generate_company_zip
      when "monthly_summary_pdf"
        generate_monthly_summary_pdf
      end
    end

    private

    attr_reader :report_export, :parameters, :period_start, :generated_at

    def generate_person_pdf
      employee = Employee.includes(:tags).find(parameters.fetch(:employee_id))
      report_export.update!(progress: 35)
      pdf = employee_pdf(employee)
      filename = Filenames.employee_pdf(employee, period_start)

      attach_artifact(pdf, filename: filename, content_type: PDF_CONTENT_TYPE)
    end

    def generate_tag_zip
      tag = Tag.active.find(parameters.fetch(:tag_id))
      employees = MonthlyEmployeeScope.resolve(month: period_start.month, year: period_start.year, tag: tag).to_a
      filename = Filenames.tag_zip(tag, period_start)

      with_zip_for(employees) do |zip_file|
        attach_artifact(zip_file, filename: filename, content_type: ZIP_CONTENT_TYPE)
      end
    end

    def generate_company_zip
      employees = MonthlyEmployeeScope.resolve(month: period_start.month, year: period_start.year).to_a
      filename = Filenames.company_zip(period_start)

      with_zip_for(employees) do |zip_file|
        attach_artifact(zip_file, filename: filename, content_type: ZIP_CONTENT_TYPE)
      end
    end

    def generate_monthly_summary_pdf
      report_export.update!(progress: 35)
      report = MonthlySummaryReport.new(month: period_start.month, year: period_start.year).to_h
      pdf = PdfRenderer.render(template: "admin/reports/pdf/monthly_summary", assigns: pdf_assigns(report))
      filename = Filenames.monthly_summary_pdf(period_start)

      attach_artifact(pdf, filename: filename, content_type: PDF_CONTENT_TYPE)
    end

    def employee_pdf(employee)
      report = MonthlyEmployeeReport.new(employee: employee, month: period_start.month, year: period_start.year).to_h
      report_export.update!(progress: [ report_export.progress, 55 ].max)

      PdfRenderer.render(template: "admin/reports/pdf/employee", assigns: pdf_assigns(report))
    end

    def pdf_assigns(report)
      {
        report: report,
        report_generated_by: report_export.manager,
        report_generated_at: generated_at
      }
    end

    def with_zip_for(employees)
      report_export.update!(progress: 20)

      Tempfile.create([ "report-export-#{report_export.id}-", ".zip" ], binmode: true) do |file|
        file.close

        Zip::File.open(file.path, create: true) do |zip|
          if employees.empty?
            zip.get_output_stream(I18n.t("admin.reports.exports.empty_zip.filename")) do |entry|
              entry.write(I18n.t("admin.reports.exports.empty_zip.body"))
            end
          end

          employees.each_with_index do |employee, index|
            zip.get_output_stream(unique_employee_filename(employee, index)) do |entry|
              entry.write(employee_pdf(employee))
            end
            update_zip_progress(index + 1, employees.size)
          end
        end

        File.open(file.path, "rb") do |zip_file|
          yield zip_file
        end
      end
    end

    def unique_employee_filename(employee, index)
      "#{(index + 1).to_s.rjust(3, "0")}-#{Filenames.employee_pdf(employee, period_start)}"
    end

    def update_zip_progress(done_count, total_count)
      return if total_count.zero?

      progress = 20 + ((done_count.to_f / total_count) * 70).round
      report_export.update!(progress: [ progress, 95 ].min)
    end

    def attach_artifact(bytes, filename:, content_type:)
      report_export.update!(progress: 96)
      report_export.artifact.attach(
        io: artifact_io(bytes),
        filename: filename,
        content_type: content_type
      )
      report_export.mark_completed!(filename: filename, content_type: content_type)
    end

    def artifact_io(bytes)
      return StringIO.new(bytes) unless bytes.respond_to?(:read)

      bytes.rewind
      bytes
    end
  end
end
