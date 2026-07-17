class Admin::BaseController < ApplicationController
  layout "admin"

  before_action :authenticate_manager!
  before_action :set_manager

  private

  def set_manager
    @manager = current_manager
  end
end
