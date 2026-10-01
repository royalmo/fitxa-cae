class ApplicationController < ActionController::Base
  FORM_METADATA_PARAM_KEYS = %w[authenticity_token commit].freeze
  MINIMUM_BROWSER_VERSIONS = {
    safari: 16.4,
    chrome: 108,
    firefox: 121,
    opera: 94,
    ie: false
  }.freeze

  include EmployeeAuthentication
  include ManagerAuthentication
  include AuditRecording

  # Keep the floor close to the app's importmap, CSS :has, and viewport-unit requirements.
  allow_browser versions: MINIMUM_BROWSER_VERSIONS, unless: :browser_check_skipped?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_employee!, if: :employee_authentication_required?
  before_action :discard_form_metadata_params

  helper_method :hide_hr_contact_form?

  private

  def discard_form_metadata_params
    FORM_METADATA_PARAM_KEYS.each { |key| params.delete(key) }
  end

  def hide_hr_contact_form?
    Rails.configuration.x.hide_hr_contact_form
  end

  def render_forbidden
    @admin_error_page = request.path == admin_root_path || request.path.start_with?("#{admin_root_path}/")
    @error_key = :forbidden
    @error_code = "403"
    @human_resources_email = Rails.configuration.x.human_resources_email

    render "errors/show", status: :forbidden, layout: (@admin_error_page ? "admin" : "employee")
  end

  def employee_authentication_required?
    controller_path.start_with?("employee/") && controller_name != "sessions"
  end

  def browser_check_skipped?
    controller_path == "errors"
  end
end
