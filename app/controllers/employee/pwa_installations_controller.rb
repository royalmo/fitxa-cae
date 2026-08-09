class Employee::PwaInstallationsController < ApplicationController
  layout "employee_auth"

  skip_before_action :authenticate_employee!

  before_action :set_pwa_install_platform

  def show
  end

  private

  def set_pwa_install_platform
    @pwa_install_platform = pwa_install_platform_from_user_agent
  end

  def pwa_install_platform_from_user_agent
    user_agent = request.user_agent.to_s

    return "ios" if ios_user_agent?(user_agent)
    return "android" if user_agent.match?(/Android/i)

    "android"
  end

  def ios_user_agent?(user_agent)
    user_agent.match?(/iPad|iPhone|iPod/i) ||
      (user_agent.match?(/Macintosh/i) && user_agent.match?(/Mobile/i))
  end
end
