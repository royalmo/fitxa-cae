class Admin::TagsController < Admin::BaseController
  TAGS_PER_PAGE = 20

  def index
    load_index_tags
    @new_tag ||= Tag.new(active: true, color: "#e30613")
  end

  def create
    @tag = Tag.new(tag_params.merge(active: true))

    if @tag.save
      redirect_to admin_tags_path, notice: t("admin.flash.tag_created")
    else
      render_index_with_form_error(@tag)
    end
  end

  def update
    @tag = Tag.find(params[:id])

    if @tag.update(tag_params)
      redirect_to admin_tags_path, notice: t("admin.flash.tag_updated")
    else
      render_index_with_form_error(@tag)
    end
  end

  def activation
    @tag = Tag.find(params[:id])
    target_active = ActiveModel::Type::Boolean.new.cast(tag_activation_params[:active])

    if @tag.update(active: target_active)
      redirect_back fallback_location: admin_tags_path,
        notice: t(target_active ? "admin.flash.tag_activated" : "admin.flash.tag_deactivated")
    else
      redirect_back fallback_location: admin_tags_path, alert: t("admin.flash.tag_activation_failed")
    end
  end

  private

  def load_index_tags
    @tags = paginate_admin_relation(
      filtered_tags.order(:name, :id),
      per_page: TAGS_PER_PAGE
    ).to_a
    @employee_counts_by_tag_id = employee_counts_by_tag_id(@tags)
  end

  def filtered_tags
    tags = Tag.all
    tags = tags.where(active: true) if params[:status] == "active"
    tags = tags.where(active: false) if params[:status] == "disabled"

    if params[:q].present?
      query = "%#{params[:q].to_s.downcase}%"
      tags = tags.where("LOWER(name) LIKE ?", query)
    end

    tags
  end

  def tag_params
    params.require(:tag).permit(:name, :color)
  end

  def tag_activation_params
    params.require(:tag).permit(:active)
  end

  def employee_counts_by_tag_id(tags)
    tag_ids = tags.map(&:id)
    return {} if tag_ids.empty?

    Employee.joins(:tags).where(tags: { id: tag_ids }).group("tags.id").count
  end

  def render_index_with_form_error(tag)
    load_index_tags
    @new_tag = tag.persisted? ? Tag.new(active: true, color: "#e30613") : tag
    @tags = @tags.map { |listed_tag| listed_tag.id == tag.id ? tag : listed_tag }
    @open_tag_form = tag

    render :index, status: :unprocessable_entity
  end
end
