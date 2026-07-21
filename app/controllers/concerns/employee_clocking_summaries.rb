module EmployeeClockingSummaries
  extend ActiveSupport::Concern

  PendingClockingSwipe = Struct.new(:kind, :swipe_at, :pending_change, keyword_init: true) do
    def entry?
      kind.to_s == "entry"
    end

    def exit?
      kind.to_s == "exit"
    end

    def pending_requested?
      pending_change == :requested
    end

    def pending_invalidated?
      pending_change == :invalidated
    end
  end

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
    swipes_by_date = swipes.group_by { |swipe| swipe.swipe_at.to_date }
    corrections_by_date = corrections.group_by(&:day)
    pending_correction_dates = corrections.select { |correction| pending_clocking_correction?(correction) }.map(&:day)
    dates = (swipes_by_date.keys + pending_correction_dates).uniq.sort

    dates.map do |date|
      day_swipes = swipes_by_date.fetch(date, [])
      day_corrections = corrections_by_date.fetch(date, [])
      display_swipes = clocking_display_swipes(day_swipes, day_corrections)
      effective_swipes = display_swipes.reject { |swipe| pending_invalidated_swipe?(swipe) }

      {
        date: date,
        entry_at: effective_swipes.find(&:entry?)&.swipe_at,
        exit_at: effective_swipes.reverse.find(&:exit?)&.swipe_at,
        swipes_count: effective_swipes.count,
        swipes: display_swipes,
        worked_seconds: Swipe.paired_work_seconds(effective_swipes),
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

  def clocking_display_swipes(day_swipes, day_corrections)
    pending_corrections = day_corrections.select { |correction| pending_clocking_correction?(correction) }
    invalidated_swipe_ids = pending_corrections.flat_map do |correction|
      pending_invalidated_swipe_ids(correction)
    end.map(&:to_i)
    existing_swipes = day_swipes.map do |swipe|
      if invalidated_swipe_ids.include?(swipe.id)
        PendingClockingSwipe.new(kind: swipe.kind, swipe_at: swipe.swipe_at, pending_change: :invalidated)
      else
        swipe
      end
    end

    (existing_swipes + pending_corrections.flat_map { |correction| pending_requested_swipes(correction) })
      .sort_by { |swipe| [ swipe.swipe_at, pending_requested_swipe?(swipe) ? 1 : 0 ] }
  end

  def pending_requested_swipes(correction)
    Array(correction.details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      kind = requested_swipe["kind"].to_s
      swipe_at = pending_requested_swipe_at(correction, requested_swipe)
      next unless Swipe.kinds.key?(kind) && swipe_at

      PendingClockingSwipe.new(kind: kind, swipe_at: swipe_at, pending_change: :requested)
    end
  end

  def pending_clocking_correction?(correction)
    correction.pending? && (
      pending_invalidated_swipe_ids(correction).any? ||
      Array(correction.details&.fetch("requested_swipes", nil)).any?
    )
  end

  def pending_invalidated_swipe_ids(correction)
    Array(correction.details&.fetch("invalidated_swipe_ids", nil))
  end

  def pending_requested_swipe_at(correction, requested_swipe)
    return if requested_swipe["hour"].blank?

    Time.zone.parse("#{correction.day.iso8601} #{requested_swipe["hour"]}")
  rescue ArgumentError
    nil
  end

  def pending_requested_swipe?(swipe)
    swipe.respond_to?(:pending_requested?) && swipe.pending_requested?
  end

  def pending_invalidated_swipe?(swipe)
    swipe.respond_to?(:pending_invalidated?) && swipe.pending_invalidated?
  end
end
