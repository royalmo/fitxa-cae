module Reports
  class MonthlyEmployeeScope
    def self.resolve(month:, year:, tag: nil)
      new(month:, year:, tag:).resolve
    end

    def initialize(month:, year:, tag: nil)
      @period_start = Date.new(year.to_i, month.to_i, 1)
      @period_end = @period_start.end_of_month
      @period_range = @period_start.beginning_of_day...@period_end.next_day.beginning_of_day
      @tag = tag
    end

    def resolve
      employees = Employee.where(id: employee_ids)
      employees = employees.joins(:tags).where(tags: { id: @tag.id }) if @tag

      employees.includes(:tags).order(:last_name, :first_name, :id)
    end

    private

    def employee_ids
      (active_employee_ids + swiped_employee_ids).uniq
    end

    def active_employee_ids
      Employee.active_during(@period_range).pluck(:id)
    end

    def swiped_employee_ids
      Swipe.kept
        .where(swipe_at: @period_range)
        .distinct
        .pluck(:employee_id)
    end
  end
end
