class Admin::CorrectionsController < ApplicationController
  layout "admin"

  def index
    @manager = demo_current_manager
    @corrections = demo_admin_corrections
  end

  def approve
    redirect_to admin_corrections_path, notice: t("admin.flash.correction_approved")
  end

  def reject
    redirect_to admin_corrections_path, notice: t("admin.flash.correction_rejected")
  end
end
