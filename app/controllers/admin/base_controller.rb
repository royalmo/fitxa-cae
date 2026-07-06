class Admin::BaseController < ApplicationController
  layout "admin"

  helper_method :current_manager

  before_action :set_manager

  private

  def current_manager
    @current_manager ||= if session[:manager_id]
      Manager.find_by(id: session[:manager_id], active: true)
    else
      Manager.where(active: true).order(:id).first
    end
  end

  def set_manager
    @manager = current_manager
  end
end
