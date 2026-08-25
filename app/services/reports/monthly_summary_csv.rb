require "csv"

module Reports
  class MonthlySummaryCsv
    def initialize(report:)
      @report = report
    end

    def to_csv
      CSV.generate do |csv|
        csv << headers

        report.fetch(:rows).each do |row|
          csv << row_values(row)
        end
      end
    end

    private

    attr_reader :report

    def headers
      I18n.t("admin.reports.csv.monthly_summary.headers")
    end

    def row_values(row)
      employee = row.fetch(:employee)

      [
        employee_name(employee, active: row.fetch(:active)),
        employee.national_id,
        row.fetch(:tags).map(&:name).join(";"),
        row.fetch(:swipes_count),
        duration_text(row.fetch(:worked_seconds)),
        note_text(row.fetch(:note_key))
      ]
    end

    def employee_name(employee, active:)
      name = employee.full_name.presence || employee.first_name

      active ? name : "#{name} (#{I18n.t("admin.reports.csv.monthly_summary.inactive")})"
    end

    def duration_text(total_seconds)
      minutes = [ total_seconds.to_i / 60, 0 ].max
      hours, remaining_minutes = minutes.divmod(60)

      "#{hours} h #{remaining_minutes.to_s.rjust(2, "0")} min"
    end

    def note_text(note_key)
      return nil if note_key.blank?

      I18n.t("admin.reports.csv.monthly_summary.notes.#{note_key}")
    end
  end
end
