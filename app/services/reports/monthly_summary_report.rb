module Reports
  class MonthlySummaryReport
    attr_reader :period_start, :period_end

    def initialize(month:, year:)
      @period_start = Date.new(year.to_i, month.to_i, 1)
      @period_end = @period_start.end_of_month
    end

    def to_h
      {
        period_start: period_start,
        period_end: period_end,
        totals: totals,
        rows: rows
      }
    end

    private

    def totals
      {
        people_count: employees.size,
        active_people_count: employees.count(&:active?),
        people_with_swipes_count: swipes_by_employee_id.keys.size,
        swipes_count: swipes.size,
        worked_seconds: rows.sum { |row| row[:worked_seconds] }
      }
    end

    def rows
      @rows ||= employees.map do |employee|
        employee_swipes = swipes_by_employee_id.fetch(employee.id, [])

        {
          employee: employee,
          tags: employee.tags.sort_by { |tag| tag.name.downcase },
          active: employee.active?,
          swipes_count: employee_swipes.size,
          worked_seconds: employee_swipes.group_by { |swipe| swipe.swipe_at.in_time_zone.to_date }
            .values
            .sum { |day_swipes| Swipe.paired_work_seconds(day_swipes) }
        }
      end
    end

    def employees
      @employees ||= MonthlyEmployeeScope.resolve(month: period_start.month, year: period_start.year).to_a
    end

    def swipes
      @swipes ||= Swipe.kept
        .where(employee_id: employees.map(&:id), swipe_at: period_start.beginning_of_day..period_end.end_of_day)
        .chronological
        .to_a
    end

    def swipes_by_employee_id
      @swipes_by_employee_id ||= swipes.group_by(&:employee_id)
    end
  end
end
