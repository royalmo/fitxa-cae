require "csv"

module Reports
  class MonthlySummaryCsv
    HEADERS = [ "Persona", "DNI/NIE", "Etiquetes", "Fitxatges", "Hores" ].freeze

    def initialize(report:)
      @report = report
    end

    def to_csv
      CSV.generate do |csv|
        csv << HEADERS

        report.fetch(:rows).each do |row|
          csv << row_values(row)
        end
      end
    end

    private

    attr_reader :report

    def row_values(row)
      employee = row.fetch(:employee)

      [
        employee_name(employee, active: row.fetch(:active)),
        employee.national_id,
        row.fetch(:tags).map(&:name).join(";"),
        row.fetch(:swipes_count),
        duration_text(row.fetch(:worked_seconds))
      ]
    end

    def employee_name(employee, active:)
      name = employee.full_name.presence || employee.first_name

      active ? name : "#{name} (inactiva)"
    end

    def duration_text(total_seconds)
      minutes = [ total_seconds.to_i / 60, 0 ].max
      hours, remaining_minutes = minutes.divmod(60)

      "#{hours} h #{remaining_minutes.to_s.rjust(2, "0")} min"
    end
  end
end
