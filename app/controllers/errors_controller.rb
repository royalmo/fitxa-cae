class ErrorsController < ApplicationController
  include AdminChrome

  layout :error_layout

  ERROR_PAGES = {
    bad_request: [ "400", :bad_request ],
    not_found: [ "404", :not_found ],
    not_acceptable: [ "406", :not_acceptable ],
    unprocessable_entity: [ "422", :unprocessable_entity ],
    internal_server_error: [ "500", :internal_server_error ]
  }.freeze

  def bad_request
    render_error(:bad_request)
  end

  def not_found
    render_error(:not_found)
  end

  def not_acceptable
    render_error(:not_acceptable)
  end

  def unprocessable_entity
    render_error(:unprocessable_entity)
  end

  def internal_server_error
    render_error(:internal_server_error)
  end

  private

  def render_error(key)
    code, status = ERROR_PAGES.fetch(key)

    @admin_error_page = admin_error_request?
    set_admin_chrome if @admin_error_page
    @error_key = key
    @error_code = code
    @human_resources_email = Rails.configuration.x.human_resources_email

    render :show, status: status
  end

  def error_layout
    @admin_error_page ? "admin" : "employee"
  end

  def admin_error_request?
    original_path = request.get_header("action_dispatch.original_path").presence || request.path

    original_path == admin_root_path || original_path.start_with?("#{admin_root_path}/")
  end

  def set_admin_chrome
    set_admin_current_manager
    set_admin_topbar
  end
end
