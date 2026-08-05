class CleanupReportExportsJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    ReportExport.expired_for_cleanup(now).find_each(&:mark_expired!)
  end
end
