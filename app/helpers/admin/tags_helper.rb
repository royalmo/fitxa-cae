module Admin::TagsHelper
  def admin_tag_status(tag)
    tag.active? ? :active : :disabled
  end
end
