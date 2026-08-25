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
        active_people_count: period_active_employee_ids.size,
        people_with_swipes_count: swipes_by_employee_id.keys.size,
        swipes_count: swipes.size,
        worked_seconds: rows.sum { |row| row[:worked_seconds] }
      }
    end

    def rows
      @rows ||= employees.map do |employee|
        employee_swipes = swipes_by_employee_id.fetch(employee.id, [])
        daily_swipes = employee_swipes.group_by { |swipe| swipe.swipe_at.in_time_zone.to_date }.values
        odd_swipes = daily_swipes.any? { |day_swipes| day_swipes.size.odd? }
        pending_corrections = pending_correction_employee_ids.include?(employee.id)

        {
          employee: employee,
          tags: employee.tags.sort_by { |tag| tag.name.downcase },
          active: period_active_employee_ids.include?(employee.id),
          swipes_count: employee_swipes.size,
          odd_swipes: odd_swipes,
          pending_corrections: pending_corrections,
          note_key: note_key(swipes_count: employee_swipes.size, odd_swipes: odd_swipes, pending_corrections: pending_corrections),
          worked_seconds: daily_swipes.sum { |day_swipes| Swipe.paired_work_seconds(day_swipes) }
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

    def period_range
      @period_range ||= period_start.beginning_of_day...period_end.next_day.beginning_of_day
    end

    def period_active_employee_ids
      @period_active_employee_ids ||= Employee.active_during(period_range).where(id: employees.map(&:id)).ids
    end

    def pending_correction_employee_ids
      return @pending_correction_employee_ids if defined?(@pending_correction_employee_ids)

      employee_ids = employees.map(&:id)
      @pending_correction_employee_ids = if employee_ids.empty?
        []
      else
        SwipeCorrection.pending
          .where(employee_id: employee_ids, day: period_start..period_end)
          .distinct
          .pluck(:employee_id)
      end
    end

    def note_key(swipes_count:, odd_swipes:, pending_corrections:)
      return :erroneous_swipes if odd_swipes
      return :pending_corrections if pending_corrections
      return :no_swipes if swipes_count.zero?

      nil
    end
  end
end
