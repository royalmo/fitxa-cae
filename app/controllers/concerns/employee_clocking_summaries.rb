module EmployeeClockingSummaries
  extend ActiveSupport::Concern

  private

  def current_clock_state(employee)
    open_entry = employee.open_entry_swipe

    {
      clocked_in: open_entry.present?,
      clocked_in_at: open_entry&.swipe_at,
      latest_swipe: employee.latest_swipe
    }
  end

  def week_clocking_summary(employee, date: Time.zone.today)
    start_date = date.beginning_of_week(:monday)
    end_date = date.end_of_week(:monday)
    swipes = employee.swipes.kept.where(swipe_at: start_date.beginning_of_day..end_date.end_of_day).chronological.to_a

    {
      worked_seconds: swipes.group_by { |swipe| swipe.swipe_at.to_date }.values.sum { |day_swipes| Swipe.paired_work_seconds(day_swipes) },
      days: swipes.map { |swipe| swipe.swipe_at.to_date }.uniq.count,
      corrections: employee.swipe_corrections.where(day: start_date..end_date).count
    }
  end

  def clocking_day_summaries(employee, start_date:, end_date:)
    swipes = employee.swipes.kept.where(swipe_at: start_date.beginning_of_day..end_date.end_of_day).chronological.to_a
    corrections = employee.swipe_corrections.where(day: start_date..end_date).to_a
    dates = (swipes.map { |swipe| swipe.swipe_at.to_date } + corrections.map(&:day)).uniq.sort.reverse

    dates.map do |date|
      day_swipes = swipes.select { |swipe| swipe.swipe_at.to_date == date }
      day_corrections = corrections.select { |correction| correction.day == date }

      {
        date: date,
        entry_at: day_swipes.find(&:entry?)&.swipe_at,
        exit_at: day_swipes.reverse.find(&:exit?)&.swipe_at,
        swipes_count: day_swipes.count,
        worked_seconds: Swipe.paired_work_seconds(day_swipes),
        status: clocking_day_status(day_swipes, day_corrections)
      }
    end
  end

  def clocking_day_status(swipes, corrections)
    return :corrected if corrections.any?(&:approved?)
    return :pending if corrections.any?(&:pending?)
    return :open if swipes.last&.entry?

    swipes.any? ? :complete : :empty
  end
end
