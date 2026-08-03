class Admin::CorrectionsController < Admin::BaseController
  CORRECTIONS_PER_PAGE = 20

  def index
    @filterable_statuses = SwipeCorrection.filterable_statuses
    @selected_status = selected_correction_status
    @selected_employee = selected_employee
    @selected_employee_id = @selected_employee&.id&.to_s
    @selected_tag = selected_active_tag
    @selected_tag_id = @selected_tag&.id&.to_s
    @selected_month = selected_month
    @selected_year = selected_year
    @highlight_day = selected_highlight_day
    @year_options = correction_year_options
    @corrections = paginate_admin_relation(
      filtered_corrections.order(created_at: :desc),
      per_page: CORRECTIONS_PER_PAGE
    ).to_a
    @correction_day_swipes_by_key = day_swipes_by_correction_key(@corrections)
  end

  def show
    @correction = SwipeCorrection.includes(:employee, :validator).find(params[:id])
    @day_swipes = @correction.employee.swipes.for_day(@correction.day).chronological.to_a
  end

  def day
    employee = Employee.find_by(id: params[:employee_id].presence)
    correction_day = selected_day_for_form

    unless employee && correction_day
      render json: {
        day_allowed: false,
        swipes: [],
        pending_correction: nil
      }
      return
    end

    existing_correction = existing_day_correction(employee, correction_day)

    render json: {
      day_allowed: true,
      existing_correction_html: existing_correction_prompt_html(existing_correction),
      existing_correction_blocks_form: existing_correction&.pending? || false,
      swipes: employee.swipes.kept.for_day(correction_day).chronological.map { |swipe| swipe_payload(swipe) },
      pending_correction: nil
    }
  end

  def new
    @correction = SwipeCorrection.new(
      employee: selected_employee_for_form,
      requester: current_manager,
      status: :pending,
      day: selected_day_for_form,
      details: empty_correction_details
    )
    load_correction_form_context
  end

  def create
    @correction = SwipeCorrection.new(requester: current_manager, status: :pending)
    assignment_valid = assign_correction_attributes(@correction)

    if assignment_valid && create_and_approve_correction(@correction)
      redirect_to admin_correction_path(@correction), notice: t("admin.flash.correction_created_and_approved")
    else
      @correction.errors.add(:base, t("admin.corrections.form.invalid")) if !assignment_valid && @correction.errors.empty?
      load_correction_form_context
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @correction = SwipeCorrection.find(params[:id])
    return redirect_reviewed_correction(@correction) unless @correction.pending?

    load_correction_form_context
  end

  def update
    @correction = SwipeCorrection.find(params[:id])
    return redirect_reviewed_correction(@correction) unless @correction.pending?

    if review_pending_correction_from_edit(@correction)
      redirect_to admin_correction_path(@reviewed_correction), notice: @review_notice
    else
      load_correction_form_context
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    correction = SwipeCorrection.find(params[:id])

    if correction.pending?
      approve_correction(correction, validator_comments: review_validator_comments(:approved))
      redirect_back fallback_location: admin_corrections_path, notice: t("admin.flash.correction_approved")
    else
      redirect_back fallback_location: admin_corrections_path, alert: t("admin.flash.correction_already_reviewed")
    end
  end

  def reject
    correction = SwipeCorrection.find(params[:id])

    if correction.pending?
      correction.update!(
        status: :rejected,
        validator: current_manager,
        validator_comments: review_validator_comments(:rejected)
      )
      redirect_back fallback_location: admin_corrections_path, notice: t("admin.flash.correction_rejected")
    else
      redirect_back fallback_location: admin_corrections_path, alert: t("admin.flash.correction_already_reviewed")
    end
  end

  private

  def filtered_corrections
    corrections = SwipeCorrection.includes(:employee, :validator)
    corrections = corrections.where(status: @selected_status) if @selected_status
    corrections = corrections.where(employee_id: @selected_employee_id) if @selected_employee_id.present?
    corrections = corrections.joins(employee: :tags).where(tags: { id: @selected_tag_id }).distinct if @selected_tag_id.present?
    corrections = filter_corrections_by_period(corrections)
    corrections
  end

  def redirect_reviewed_correction(correction)
    redirect_to admin_correction_path(correction), alert: t("admin.flash.correction_already_reviewed")
  end

  def review_validator_comments(status)
    params[:validator_comments].presence || t("admin.corrections.review.#{status}")
  end

  def load_correction_form_context
    @employees = Employee.order(:last_name, :first_name, :id)
    @identity_ready = @correction.employee_id.present? && @correction.day.present?
    @existing_day_correction = existing_day_correction(@correction.employee, @correction.day) if @identity_ready && !@correction.persisted?
    @form_ready = @identity_ready && !@existing_day_correction&.pending?
    @day_swipes = @correction.employee&.swipes&.kept&.for_day(@correction.day)&.chronological&.to_a || []
    @requested_swipe_rows = requested_swipe_form_rows(@correction)
  end

  def selected_employee_for_form
    Employee.find_by(id: params[:employee_id].presence)
  end

  def selected_employee
    Employee.find_by(id: params[:employee_id].presence) if params[:employee_id].present?
  end

  def selected_active_tag
    Tag.find_by(id: params[:tag_id].presence, active: true) if params[:tag_id].present?
  end

  def selected_day_for_form
    day = params[:day].presence || params[:date].presence
    Date.iso8601(day) if day.present?
  rescue Date::Error
    nil
  end

  def selected_correction_status
    params[:status].to_s if SwipeCorrection.filterable_statuses.include?(params[:status].to_s)
  end

  def selected_month
    month = Integer(params[:month].presence, exception: false)
    month if month&.between?(1, 12)
  end

  def selected_year
    year = Integer(params[:year].presence, exception: false)
    year if year&.between?(2000, 2100)
  end

  def selected_highlight_day
    Date.iso8601(params[:highlight_day].to_s) if params[:highlight_day].present?
  rescue Date::Error
    nil
  end

  def correction_year_options
    min_day = SwipeCorrection.minimum(:day)
    max_day = SwipeCorrection.maximum(:day)
    years = [ Time.zone.today.year ]
    years.concat((min_day.year..max_day.year).to_a) if min_day && max_day
    years << @selected_year if @selected_year
    years.compact.uniq.sort
  end

  def filter_corrections_by_period(corrections)
    return corrections.where(day: selected_month_range(@selected_year, @selected_month)) if @selected_year && @selected_month
    return corrections.where(day: Date.new(@selected_year, 1, 1)..Date.new(@selected_year, 12, 31)) if @selected_year
    return corrections unless @selected_month

    condition = @year_options.map { |year| selected_month_range(year, @selected_month) }
      .map { |range| correction_day_range_condition(range) }
      .reduce { |combined_condition, range_condition| combined_condition.or(range_condition) }

    condition ? corrections.where(condition) : corrections
  end

  def selected_month_range(year, month)
    first_day = Date.new(year, month, 1)
    first_day..first_day.end_of_month
  end

  def correction_day_range_condition(range)
    table = SwipeCorrection.arel_table
    table[:day].gteq(range.begin).and(table[:day].lteq(range.end))
  end

  def day_swipes_by_correction_key(corrections)
    employee_ids = corrections.map(&:employee_id).compact.uniq
    days = corrections.map(&:day).compact.uniq
    return {} if employee_ids.empty? || days.empty?

    Swipe
      .where(employee_id: employee_ids, swipe_at: days.min.beginning_of_day..days.max.end_of_day)
      .chronological
      .group_by { |swipe| [ swipe.employee_id, swipe.swipe_at.in_time_zone.to_date ] }
  end

  def assign_correction_attributes(correction)
    attributes = correction_params

    if correction.persisted?
      employee = correction.employee
      day = correction.day
    else
      employee = Employee.find_by(id: attributes[:employee_id])
      day = parsed_correction_day(attributes[:day])
      return false unless employee && day

      if pending_day_correction(employee, day)
        correction.employee = employee
        correction.day = day
        correction.errors.add(:base, t("admin.corrections.form.existing_correction"))
        return false
      end
    end

    correction.employee = employee
    correction.day = day
    correction.requester_comments = attributes[:requester_comments]
    correction.details = correction_details(attributes, day)
    true
  end

  def correction_params
    params.require(:swipe_correction).permit(
      :employee_id,
      :day,
      :requester_comments,
      :validator_comments,
      invalidated_swipe_ids: [],
      requested_swipes: [ :kind, :hour ]
    )
  end

  def correction_details(attributes, day)
    {
      "invalidated_swipe_ids" => Array(attributes[:invalidated_swipe_ids]).compact_blank.map(&:to_s),
      "requested_swipes" => normalized_requested_swipes(attributes[:requested_swipes], day)
    }
  end

  def normalized_requested_swipes(requested_swipes, day)
    requested_swipe_rows(requested_swipes).filter_map do |requested_swipe|
      kind = requested_swipe.fetch("kind", requested_swipe[:kind]).to_s
      hour = requested_swipe.fetch("hour", requested_swipe[:hour]).to_s
      next if kind.blank? && hour.blank?
      next unless Swipe.kinds.key?(kind)

      swipe_at = Time.zone.parse("#{day.iso8601} #{hour}")
      { "kind" => kind, "hour" => swipe_at.strftime("%H:%M:%S") }
    rescue ArgumentError
      nil
    end
  end

  def requested_swipe_rows(requested_swipes)
    case requested_swipes
    when ActionController::Parameters, Hash
      requested_swipes.values
    else
      Array(requested_swipes)
    end
  end

  def parsed_correction_day(day)
    Date.iso8601(day.to_s)
  rescue Date::Error
    nil
  end

  def requested_swipe_form_rows(correction)
    Array(correction.details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      next if requested_swipe["kind"].blank? || requested_swipe["hour"].blank?

      { "kind" => requested_swipe["kind"], "hour" => requested_swipe["hour"].to_s.first(5) }
    end
  end

  def empty_correction_details
    { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
  end

  def existing_day_correction(employee, day)
    return unless employee && day

    corrections = employee.swipe_corrections.where(day: day)
    pending_day_correction(employee, day) || corrections.order(created_at: :desc).first
  end

  def pending_day_correction(employee, day)
    return unless employee && day

    employee.swipe_corrections.pending.where(day: day).order(created_at: :desc).first
  end

  def existing_correction_prompt_html(correction)
    return unless correction

    render_to_string(
      partial: "admin/corrections/existing_correction_prompt",
      formats: [ :html ],
      locals: { correction: correction }
    )
  end

  def swipe_payload(swipe)
    {
      id: swipe.id.to_s,
      kind: swipe.kind,
      time: helpers.l(swipe.swipe_at, format: :hour_minute)
    }
  end

  def invalidated_swipes_by_id(correction)
    swipe_ids = Array(correction.details&.fetch("invalidated_swipe_ids", nil)).compact_blank
    return {} if swipe_ids.empty?

    correction.employee.swipes.where(id: swipe_ids).index_by { |swipe| swipe.id.to_s }
  end

  def review_pending_correction_from_edit(correction)
    attributes = correction_params
    modified_details = correction_details(attributes, correction.day)
    hr_comment = attributes[:validator_comments].to_s

    if correction_details_changed?(correction.details, modified_details)
      approve_with_modified_details(correction, modified_details, hr_comment)
    else
      approve_correction(
        correction,
        validator_comments: hr_comment.presence || t("admin.corrections.review.approved")
      )
      @reviewed_correction = correction
      @review_notice = t("admin.flash.correction_approved")
    end

    true
  rescue ActiveRecord::RecordInvalid
    correction.details = modified_details
    correction.validator_comments = hr_comment
    correction.errors.add(:base, t("admin.corrections.form.invalid")) if correction.errors.empty?
    false
  end

  def approve_with_modified_details(correction, modified_details, hr_comment)
    SwipeCorrection.transaction do
      correction.update!(
        status: :rejected,
        validator: current_manager,
        validator_comments: t("admin.corrections.review.approved_with_modifications")
      )
      @approved_correction = SwipeCorrection.create!(
        employee: correction.employee,
        day: correction.day,
        requester: current_manager,
        requester_comments: hr_comment,
        details: modified_details,
        status: :pending
      )
      approve_correction(@approved_correction)
    end

    @reviewed_correction = @approved_correction
    @review_notice = t("admin.flash.correction_approved_with_modifications")
  end

  def correction_details_changed?(previous_details, next_details)
    normalized_correction_details(previous_details) != normalized_correction_details(next_details)
  end

  def normalized_correction_details(details)
    {
      "invalidated_swipe_ids" => Array(details&.fetch("invalidated_swipe_ids", nil)).compact_blank.map(&:to_s).sort,
      "requested_swipes" => normalized_correction_requested_swipes(details)
    }
  end

  def normalized_correction_requested_swipes(details)
    Array(details&.fetch("requested_swipes", nil)).filter_map do |requested_swipe|
      kind = requested_swipe.fetch("kind", requested_swipe[:kind]).to_s
      hour = requested_swipe.fetch("hour", requested_swipe[:hour]).to_s
      next if kind.blank? && hour.blank?

      { "kind" => kind, "hour" => hour.first(8) }
    end.sort_by { |requested_swipe| [ requested_swipe["hour"], requested_swipe["kind"] ] }
  end

  def approve_correction(correction, validator_comments: t("admin.corrections.review.approved"))
    SwipeCorrection.transaction do
      remove_invalidated_swipes(correction)
      create_requested_swipes(correction)
      correction.update!(
        status: :approved,
        validator: current_manager,
        validator_comments: validator_comments
      )
    end
  end

  def create_and_approve_correction(correction, validator_comments: t("admin.corrections.review.approved"))
    SwipeCorrection.transaction do
      correction.save!
      approve_correction(correction, validator_comments: validator_comments)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def remove_invalidated_swipes(correction)
    swipe_ids = Array(correction.details&.fetch("invalidated_swipe_ids", nil)).compact_blank
    return if swipe_ids.empty?

    correction.employee.swipes.kept.where(id: swipe_ids).update_all(removed: true, updated_at: Time.current)
  end

  def create_requested_swipes(correction)
    Array(correction.details&.fetch("requested_swipes", nil)).each do |requested_swipe|
      kind = requested_swipe["kind"].to_s
      swipe_at = requested_swipe_at(correction, requested_swipe)
      next unless Swipe.kinds.key?(kind) && swipe_at

      correction.employee.swipes.create!(
        kind: kind,
        swipe_at: swipe_at,
        metadata: "admin_correction:#{correction.id}",
        forged: true
      )
    rescue ArgumentError
      next
    end
  end

  def requested_swipe_at(correction, requested_swipe)
    return if requested_swipe["hour"].blank?

    Time.zone.parse("#{correction.day.iso8601} #{requested_swipe["hour"]}")
  end
end
