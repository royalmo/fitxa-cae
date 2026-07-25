module Admin::ClassificationsHelper
  def admin_classification_status(classification)
    classification.active? ? :active : :disabled
  end
end
