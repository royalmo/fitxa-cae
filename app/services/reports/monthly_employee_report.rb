module Reports
  class MonthlyEmployeeReport
    attr_reader :employee, :period_start, :period_end

    def initialize(employee:, month:, year:)
      @employee = employee
      @period_start = Date.new(year.to_i, month.to_i, 1)
      @period_end = @period_start.end_of_month
    end

    def to_h
      {
        employee: employee,
        period_start: period_start,
        period_end: period_end,
        tags: employee.tags.sort_by { |tag| tag.name.downcase },
        totals: totals,
        correction_counts: correction_counts,
        days: day_rows
      }
    end

    private

    def totals
      {
        swipes_count: swipes.size,
        worked_seconds: swipes_by_date.values.sum { |day_swipes| Swipe.paired_work_seconds(day_swipes) },
        worked_days: swipes_by_date.keys.size,
        corrections_count: corrections.size
      }
    end

    def day_rows
      (period_start..period_end).map do |date|
        day_swipes = swipes_by_date.fetch(date, [])

        {
          date: date,
          swipes: day_swipes.map { |swipe| swipe_payload(swipe) },
          swipes_count: day_swipes.size,
          worked_seconds: Swipe.paired_work_seconds(day_swipes),
          corrections: corrections_by_date.fetch(date, [])
        }
      end
    end

    def swipe_payload(swipe)
      {
        kind: swipe.kind,
        swipe_at: swipe.swipe_at,
        forged: swipe.forged?
      }
    end

    def swipes
      @swipes ||= employee.swipes.kept.where(swipe_at: period_start.beginning_of_day..period_end.end_of_day).chronological.to_a
    end

    def corrections
      @corrections ||= employee.swipe_corrections.where(day: period_start..period_end).order(:day, :created_at).to_a
    end

    def swipes_by_date
      @swipes_by_date ||= swipes.group_by { |swipe| swipe.swipe_at.in_time_zone.to_date }
    end

    def corrections_by_date
      @corrections_by_date ||= corrections.group_by(&:day)
    end

    def correction_counts
      SwipeCorrection.statuses.keys.index_with { |status| corrections.count { |correction| correction.status == status } }
    end
  end
end
