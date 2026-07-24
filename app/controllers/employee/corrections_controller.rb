class Employee::CorrectionsController < ApplicationController
  CORRECTIONS_PER_PAGE = 10

  layout "employee"

  def index
    @employee = current_employee
    @filterable_statuses = SwipeCorrection.filterable_statuses
    @selected_status = selected_correction_status
    @min_correction_month, @max_correction_month = correction_month_bounds
    @selected_month = selected_correction_month

    filtered_corrections = filtered_correction_scope
    @corrections_count = filtered_corrections.count
    @total_pages = [ (@corrections_count.to_f / CORRECTIONS_PER_PAGE).ceil, 1 ].max
    @page = [ requested_page, @total_pages ].min
    @corrections_range_start = ((@page - 1) * CORRECTIONS_PER_PAGE) + 1 if @corrections_count.positive?
    @previous_page = @page - 1 if @page > 1
    @next_page = @page + 1 if @page < @total_pages
    @corrections = filtered_corrections
      .order(day: :desc, created_at: :desc)
      .offset((@page - 1) * CORRECTIONS_PER_PAGE)
      .limit(CORRECTIONS_PER_PAGE)
    @corrections_range_end = @corrections_range_start + @corrections.size - 1 if @corrections_range_start
    @correction_invalidated_swipes_by_id = invalidated_swipes_by_id(@corrections)
  end

  def new
    @employee = current_employee
    @correction_date_range = correction_date_range
    load_correction_form_context(correction_form_day)
  end

  def show
    @employee = current_employee
    @correction = @employee.swipe_corrections.find(params[:id])

    if @correction.pending?
      redirect_to new_correction_path(day: @correction.day.iso8601)
      return
    end

    @invalidated_swipes = @employee.swipes.where(id: correction_invalidated_swipe_ids(@correction)).chronological
    @requested_swipes = requested_swipes_for_form(@correction)
  end

  def day
    @employee = current_employee
    correction_day = parsed_date(params[:date].presence || params[:day])

    unless correction_day_allowed?(correction_day)
      render json: {
        day_allowed: false,
        error: t("employee.corrections.create.date_out_of_range"),
        swipes: [],
        pending_correction: nil
      }
      return
    end

    pending_correction = pending_correction_for(correction_day)

    render json: {
      day_allowed: true,
      swipes: swipes_for_day(correction_day).map { |swipe| swipe_payload(swipe) },
      pending_correction: pending_correction_payload(pending_correction)
    }
  end

  def create
    @employee = current_employee
    @correction_date_range = correction_date_range
    @correction = correction_for_submission

    correction_request_errors.each do |message|
      @correction.errors.add(:base, message)
    end

    if @correction.errors.empty? && @correction.save
      redirect_to corrections_path, notice: t("employee.flash.correction_requested")
    else
      load_correction_form_context(parsed_correction_day, correction: @correction)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    correction = current_employee.swipe_corrections.pending.find(params[:id])
    correction.soft_delete!

    redirect_to corrections_path, notice: correction_deleted_flash(correction)
  end

  def restore
    correction = current_employee.swipe_corrections.deleted.pending.find(params[:id])
    correction.restore!

    redirect_to new_correction_path(day: correction.day.iso8601), notice: t("employee.flash.correction_restored")
  rescue ActiveRecord::RecordInvalid
    redirect_to corrections_path, alert: t("employee.flash.correction_restore_failed")
  end

  private

  def filtered_correction_scope
    scope = @employee.swipe_corrections
    scope = scope.where(status: @selected_status) if @selected_status
    scope = scope.where(day: @selected_month..@selected_month.end_of_month) if @selected_month
    scope
  end

  def selected_correction_status
    params[:status].to_s if SwipeCorrection.filterable_statuses.include?(params[:status].to_s)
  end

  def selected_correction_month
    requested_correction_month || latest_correction_month || Time.zone.today.beginning_of_month
  end

  def requested_correction_month
    return if params[:month].blank? && params[:year].blank?

    if params[:year].blank? && params[:month].to_s.match?(/\A\d{4}-\d{1,2}\z/)
      return Date.strptime(params[:month].to_s, "%Y-%m")
    end

    year = requested_correction_year
    month = requested_correction_month_number(year)
    return unless month&.between?(1, 12) && year&.positive?

    Date.new(year, month, 1)
  rescue Date::Error
    nil
  end

  def requested_correction_year
    requested_year = Integer(params[:year], exception: false)
    return requested_year if requested_year

    @min_correction_month.year if @min_correction_month.year == @max_correction_month.year
  end

  def requested_correction_month_number(year)
    requested_month = Integer(params[:month], exception: false)
    return requested_month if requested_month
    return unless year

    if year <= @min_correction_month.year
      @min_correction_month.month
    elsif year >= @max_correction_month.year
      @max_correction_month.month
    else
      1
    end
  end

  def correction_month_bounds
    months = @employee.swipe_corrections.pluck(:day).map(&:beginning_of_month)
    months << Time.zone.today.beginning_of_month
    months.compact!

    [ months.min, months.max ]
  end

  def latest_correction_month
    @employee.swipe_corrections.maximum(:day)&.beginning_of_month
  end

  def requested_page
    page = Integer(params[:page], exception: false)

    page&.positive? ? page : 1
  end

  def invalidated_swipes_by_id(corrections)
    swipe_ids = corrections.flat_map { |correction| correction_invalidated_swipe_ids(correction) }.compact_blank.uniq
    return {} if swipe_ids.empty?

    @employee.swipes.where(id: swipe_ids).index_by { |swipe| swipe.id.to_s }
  end

  def load_correction_form_context(day, correction: nil)
    @form_has_day = correction_day_allowed?(day)
    @form_day = @form_has_day ? day : nil
    @pending_correction = pending_correction_for(@form_day)
    @correction = correction || @pending_correction || @employee.swipe_corrections.new(day: @form_day, status: :pending)
    @day_swipes = @form_has_day ? swipes_for_day(@form_day) : []
    @invalidated_swipe_ids = form_invalidated_swipe_ids(@correction)
    @requested_swipes = form_requested_swipes(@correction)
    @requested_swipes_by_kind = @requested_swipes.group_by { |requested_swipe| requested_swipe["kind"] }
    @requester_comments = correction_params[:note].presence || @correction.requester_comments
  end

  def correction_params
    params.permit(:date, :note, invalidated_swipe_ids: [], requested_swipes: [ :kind, :time ])
  end

  def parsed_correction_day
    parsed_date(correction_params[:date].presence || params[:day])
  end

  def parsed_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def correction_form_day
    parsed_correction_day if correction_day_allowed?(parsed_correction_day)
  end

  def valid_invalidated_swipe_ids
    return [] unless parsed_correction_day

    ids = Array(correction_params[:invalidated_swipe_ids]).compact_blank

    @employee.swipes.kept.for_day(parsed_correction_day).where(id: ids).pluck(:id)
  end

  def submitted_requested_swipes
    swipes = Array(correction_params[:requested_swipes]).filter_map do |requested_swipe|
      kind = (requested_swipe["kind"] || requested_swipe[:kind]).to_s
      time = (requested_swipe["time"] || requested_swipe[:time]).to_s
      next if time.blank?

      { "kind" => kind, "time" => time }
    end

    sort_requested_swipes(swipes)
  end

  def normalized_requested_swipes
    submitted_requested_swipes.filter_map do |requested_swipe|
      kind = requested_swipe["kind"]
      time = normalized_time(requested_swipe["time"])
      next unless Swipe.kinds.key?(kind) && time

      { "kind" => kind, "hour" => time }
    end
  end

  def invalid_requested_swipes?
    submitted_requested_swipes.any? do |requested_swipe|
      !Swipe.kinds.key?(requested_swipe["kind"]) || normalized_time(requested_swipe["time"]).blank?
    end
  end

  def correction_details
    {
      "invalidated_swipe_ids" => valid_invalidated_swipe_ids,
      "requested_swipes" => normalized_requested_swipes
    }
  end

  def correction_request_errors
    errors = []
    errors << t(".missing_date") unless parsed_correction_day
    errors << t(".date_out_of_range") if parsed_correction_day && !correction_day_allowed?(parsed_correction_day)
    errors << t(".invalid_requested_swipe") if invalid_requested_swipes?
    if valid_invalidated_swipe_ids.empty? && normalized_requested_swipes.empty? && !invalid_requested_swipes?
      errors << t(".missing_changes")
    end
    errors
  end

  def correction_for_submission
    correction = if correction_day_allowed?(parsed_correction_day)
      pending_correction_for(parsed_correction_day) || @employee.swipe_corrections.new(day: parsed_correction_day, status: :pending)
    else
      @employee.swipe_corrections.new(day: parsed_correction_day, status: :pending)
    end

    correction.requester = @employee if correction.requester.blank?
    correction.assign_attributes(
      requester_comments: correction_params[:note].presence,
      details: correction_details
    )
    correction
  end

  def swipes_for_day(day)
    @employee.swipes.kept.for_day(day).chronological
  end

  def pending_correction_for(day)
    @employee.swipe_corrections.pending.find_by(day: day) if day
  end

  def correction_deleted_flash(correction)
    {
      message: t("employee.flash.correction_deleted"),
      action: {
        label: t("employee.flash.undo"),
        path: restore_correction_path(correction),
        method: :post
      }
    }
  end

  def form_invalidated_swipe_ids(correction)
    return correction_invalidated_swipe_ids(correction) if correction.details.present?

    Array(correction_params[:invalidated_swipe_ids]).map(&:to_s)
  end

  def correction_invalidated_swipe_ids(correction)
    Array(correction.details&.fetch("invalidated_swipe_ids", nil)).map(&:to_s)
  end

  def form_requested_swipes(correction)
    return submitted_requested_swipes if submitted_requested_swipes.any?

    requested_swipes_for_form(correction)
  end

  def requested_swipes_for_form(correction)
    swipes = Array(correction.details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      kind = requested_swipe["kind"].to_s
      time = requested_swipe["hour"].presence
      next unless kind.present? && time.present?

      { "kind" => kind, "time" => time }
    end

    sort_requested_swipes(swipes)
  end

  def sort_requested_swipes(swipes)
    Array(swipes).each_with_index.sort_by do |requested_swipe, index|
      kind = (requested_swipe["kind"] || requested_swipe[:kind]).to_s
      kind_index = Swipe.kinds.keys.index(kind) || Swipe.kinds.size

      [ kind_index, requested_swipe_minutes(requested_swipe), index ]
    end.map(&:first)
  end

  def requested_swipe_minutes(requested_swipe)
    time = requested_swipe["hour"] || requested_swipe[:hour] || requested_swipe["time"] || requested_swipe[:time]
    time = time.to_s
    match = time.match(/\A(\d{1,2}):(\d{2})/)

    return Float::INFINITY unless match

    (match[1].to_i * 60) + match[2].to_i
  end

  def pending_correction_payload(correction)
    return unless correction

    {
      id: correction.id.to_s,
      delete_url: correction_path(correction),
      invalidated_swipe_ids: Array(correction.details&.fetch("invalidated_swipe_ids", nil)).map(&:to_s),
      requested_swipes: requested_swipes_for_form(correction),
      comment: correction.requester_comments.to_s
    }
  end

  def swipe_payload(swipe)
    {
      id: swipe.id.to_s,
      kind: swipe.kind,
      kind_text: helpers.clocking_kind_text(swipe.kind),
      time: helpers.l(swipe.swipe_at, format: :hour_minute)
    }
  end

  def normalized_time(value)
    match = value.to_s.match(/\A([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?\z/)
    return unless match

    "#{match[1].to_i.to_s.rjust(2, "0")}:#{match[2]}:#{match[3].presence || "00"}"
  end

  def correction_day_allowed?(day)
    SwipeCorrection.employee_request_day_allowed?(day)
  end

  def correction_date_range
    SwipeCorrection.employee_request_day_range
  end
end
