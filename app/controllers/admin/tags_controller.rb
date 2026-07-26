class Admin::TagsController < Admin::BaseController
  TAGS_PER_PAGE = 20

  def index
    @tags = paginate_admin_relation(
      filtered_tags.order(:name, :id),
      per_page: TAGS_PER_PAGE
    ).to_a
  end

  def new
    @tag = Tag.new(active: true, color: "#e30613")
  end

  def create
    @tag = Tag.new(tag_params)

    if @tag.save
      redirect_to admin_tags_path, notice: t("admin.flash.tag_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @tag = Tag.find(params[:id])
  end

  def update
    @tag = Tag.find(params[:id])

    if @tag.update(tag_params)
      redirect_to admin_tags_path, notice: t("admin.flash.tag_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

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
    params.require(:tag).permit(:name, :color, :active)
  end
end
