class Admin::TagSearchController < Admin::BaseController
  TAG_SEARCH_LIMIT = 8

  def index
    render partial: "admin/shared/tag_search_results", locals: {
      tags: tag_search_results,
      selected_tag_id: params[:selected_tag_id].presence
    }
  end

  private

  def tag_search_results
    tags = Tag.where(active: true).order(:name, :id)
    query = params[:q].to_s.strip
    return tags.limit(TAG_SEARCH_LIMIT) if query.blank?

    tags
      .where("LOWER(name) LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%")
      .limit(TAG_SEARCH_LIMIT)
  end
end
