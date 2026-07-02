class ApplicationController < ActionController::Base
  include DemoData
  include EmployeeAuthentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_employee!, if: :employee_authentication_required?

  private

  def employee_authentication_required?
    controller_path.start_with?("employee/") && controller_name != "sessions"
  end
end
