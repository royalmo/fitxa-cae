class Admin::CorrectionsController < Admin::BaseController
  CORRECTIONS_PER_PAGE = 20
  REQUESTED_SWIPE_FORM_ROWS = 4

  def index
    @filterable_statuses = SwipeCorrection.filterable_statuses
    @selected_status = selected_correction_status
    @selected_employee_id = params[:employee_id].presence
    @employees = Employee.order(:last_name, :first_name, :id)
    @corrections = paginate_admin_relation(
      filtered_corrections.order(created_at: :desc),
      per_page: CORRECTIONS_PER_PAGE
    ).to_a
  end

  def show
    @correction = SwipeCorrection.includes(:employee, :validator).find(params[:id])
    @invalidated_swipes_by_id = invalidated_swipes_by_id(@correction)
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

    if assignment_valid && @correction.save
      redirect_to admin_correction_path(@correction), notice: t("admin.flash.correction_created")
    else
      @correction.errors.add(:base, t("admin.corrections.form.invalid")) unless assignment_valid
      load_correction_form_context
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @correction = SwipeCorrection.find(params[:id])
    load_correction_form_context
  end

  def update
    @correction = SwipeCorrection.find(params[:id])
    assignment_valid = assign_correction_attributes(@correction)

    if assignment_valid && @correction.save
      redirect_to admin_correction_path(@correction), notice: t("admin.flash.correction_updated")
    else
      @correction.errors.add(:base, t("admin.corrections.form.invalid")) unless assignment_valid
      load_correction_form_context
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    correction = SwipeCorrection.find(params[:id])

    if correction.pending?
      approve_correction(correction)
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
        validator_comments: t("admin.corrections.review.rejected")
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
    corrections
  end

  def load_correction_form_context
    @employees = Employee.order(:last_name, :first_name, :id)
    @day_swipes = @correction.employee&.swipes&.kept&.for_day(@correction.day)&.chronological&.to_a || []
    @requested_swipe_rows = requested_swipe_form_rows(@correction)
  end

  def selected_employee_for_form
    Employee.find_by(id: params[:employee_id].presence)
  end

  def selected_day_for_form
    Date.iso8601(params[:day]) if params[:day].present?
  rescue Date::Error
    nil
  end

  def selected_correction_status
    params[:status].to_s if SwipeCorrection.filterable_statuses.include?(params[:status].to_s)
  end

  def assign_correction_attributes(correction)
    attributes = correction_params
    employee = Employee.find_by(id: attributes[:employee_id])
    day = parsed_correction_day(attributes[:day])
    return false unless employee && day

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
    rows = Array(correction.details&.fetch("requested_swipes", nil)).map do |requested_swipe|
      { "kind" => requested_swipe["kind"], "hour" => requested_swipe["hour"].to_s.first(5) }
    end

    rows << {} while rows.size < REQUESTED_SWIPE_FORM_ROWS
    rows
  end

  def empty_correction_details
    { "invalidated_swipe_ids" => [], "requested_swipes" => [] }
  end

  def invalidated_swipes_by_id(correction)
    swipe_ids = Array(correction.details&.fetch("invalidated_swipe_ids", nil)).compact_blank
    return {} if swipe_ids.empty?

    correction.employee.swipes.where(id: swipe_ids).index_by { |swipe| swipe.id.to_s }
  end

  def approve_correction(correction)
    SwipeCorrection.transaction do
      remove_invalidated_swipes(correction)
      create_requested_swipes(correction)
      correction.update!(
        status: :approved,
        validator: current_manager,
        validator_comments: t("admin.corrections.review.approved")
      )
    end
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
