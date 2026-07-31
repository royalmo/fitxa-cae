class Admin::BaseController < ApplicationController
  include AdminChrome
  include AdminPagination

  layout "admin"

  before_action :authenticate_manager!
  before_action :set_admin_current_manager
  before_action :set_admin_topbar
  after_action :record_manager_request_access

  private

  def record_manager_request_access
    current_manager&.record_request_access!(at: Time.current) unless request.head?
  end
end
