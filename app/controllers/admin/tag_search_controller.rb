class Admin::TagSearchController < Admin::BaseController
  TAG_SEARCH_LIMIT = 8

  def index
    render partial: tag_search_partial, locals: {
      tags: tag_search_results,
      selected_tag_id: params[:selected_tag_id].presence,
      selected_tag_ids: selected_tag_ids
    }
  end

  private

  def tag_search_partial
    ActiveModel::Type::Boolean.new.cast(params[:multiple]) ? "admin/shared/tag_multi_search_results" : "admin/shared/tag_search_results"
  end

  def selected_tag_ids
    params[:selected_tag_ids].to_s.split(",").compact_blank
  end

  def tag_search_results
    tags = Tag.where(active: true).order(:name, :id)
    query = params[:q].to_s.strip
    return tags.limit(TAG_SEARCH_LIMIT) if query.blank?

    tags
      .where("LOWER(name) LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%")
      .limit(TAG_SEARCH_LIMIT)
  end
end
