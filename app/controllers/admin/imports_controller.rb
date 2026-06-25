class Admin::ImportsController < ApplicationController
  layout "admin"

  def new
    @manager = demo_current_manager
  end

  def create
    redirect_to admin_employees_path, notice: t("admin.flash.import_started")
  end
end
