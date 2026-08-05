class GenerateReportExportJob < ApplicationJob
  queue_as :reports

  def perform(report_export)
    Reports::ExportGenerator.new(report_export).generate!
  rescue StandardError => error
    report_export&.mark_failed!(error.message)
    raise
  end
end
