class Employee::CorrectionsController < ApplicationController
  REQUESTED_SWIPE_KIND_BY_REQUEST_KIND = {
    "missing_entry" => "entry",
    "missing_exit" => "exit",
    "wrong_entry" => "entry",
    "wrong_exit" => "exit"
  }.freeze

  layout "employee"

  def index
    @employee = current_employee
    @corrections = @employee.swipe_corrections.order(day: :desc, created_at: :desc)
  end

  def new
    @employee = current_employee
    @correction_date_range = correction_date_range
    @correction = @employee.swipe_corrections.new(day: correction_form_day, status: :pending)
    load_recent_swipes
  end

  def create
    @employee = current_employee
    @correction_date_range = correction_date_range
    @correction = @employee.swipe_corrections.new(
      requester: @employee,
      status: :pending,
      day: parsed_correction_day,
      requester_comments: correction_params[:note].presence,
      details: correction_details
    )

    correction_request_errors.each do |message|
      @correction.errors.add(:base, message)
    end

    if @correction.errors.empty? && @correction.save
      redirect_to corrections_path, notice: t("employee.flash.correction_requested")
    else
      load_recent_swipes
      render :new, status: :unprocessable_entity
    end
  end

  private

  def load_recent_swipes
    @recent_swipes = @employee.swipes.kept.order(swipe_at: :desc, id: :desc).limit(20)
  end

  def correction_params
    params.permit(:date, :kind, :time, :note, invalidated_swipe_ids: [])
  end

  def parsed_correction_day
    Date.iso8601(correction_params[:date].to_s)
  rescue ArgumentError
    nil
  end

  def correction_form_day
    parsed_correction_day if correction_day_allowed?(parsed_correction_day)
  end

  def parsed_correction_time
    Time.zone.parse("#{parsed_correction_day.iso8601} #{correction_params[:time]}") if parsed_correction_day && correction_params[:time].present?
  rescue ArgumentError
    nil
  end

  def requested_swipe_kind
    REQUESTED_SWIPE_KIND_BY_REQUEST_KIND[correction_params[:kind].to_s]
  end

  def valid_invalidated_swipe_ids
    ids = Array(correction_params[:invalidated_swipe_ids]).compact_blank

    @employee.swipes.kept.where(id: ids).pluck(:id)
  end

  def correction_details
    requested_at = parsed_correction_time

    {
      "source" => "employee_portal",
      "request_kind" => correction_params[:kind].to_s,
      "invalidated_swipe_ids" => valid_invalidated_swipe_ids,
      "requested_swipes" => [
        {
          "kind" => requested_swipe_kind,
          "swipe_at" => requested_at&.iso8601
        }
      ],
      "comment" => correction_params[:note].to_s
    }
  end

  def correction_request_errors
    errors = []
    errors << t(".missing_date") unless parsed_correction_day
    errors << t(".date_out_of_range") if parsed_correction_day && !correction_day_allowed?(parsed_correction_day)
    errors << t(".missing_kind") unless requested_swipe_kind
    errors << t(".missing_time") unless parsed_correction_time
    errors
  end

  def correction_day_allowed?(day)
    SwipeCorrection.employee_request_day_allowed?(day)
  end

  def correction_date_range
    SwipeCorrection.employee_request_day_range
  end
end
