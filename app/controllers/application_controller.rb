class ApplicationController < ActionController::Base
  FORM_METADATA_PARAM_KEYS = %w[authenticity_token commit].freeze

  include EmployeeAuthentication
  include ManagerAuthentication
  include AuditRecording

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: :browser_check_skipped?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_employee!, if: :employee_authentication_required?
  before_action :discard_form_metadata_params

  private

  def discard_form_metadata_params
    FORM_METADATA_PARAM_KEYS.each { |key| params.delete(key) }
  end

  def employee_authentication_required?
    controller_path.start_with?("employee/") && controller_name != "sessions"
  end

  def browser_check_skipped?
    controller_path == "errors"
  end
end
