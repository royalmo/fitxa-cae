class Admin::CorrectionsController < Admin::BaseController
  def index
    @corrections = SwipeCorrection.includes(:employee, :validator).order(created_at: :desc)
  end

  def approve
    correction = SwipeCorrection.find(params[:id])

    if correction.pending?
      approve_correction(correction)
      redirect_to admin_corrections_path, notice: t("admin.flash.correction_approved")
    else
      redirect_to admin_corrections_path, alert: t("admin.flash.correction_already_reviewed")
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
      redirect_to admin_corrections_path, notice: t("admin.flash.correction_rejected")
    else
      redirect_to admin_corrections_path, alert: t("admin.flash.correction_already_reviewed")
    end
  end

  private

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
