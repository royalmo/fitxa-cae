class Admin::ClassificationsController < Admin::BaseController
  CLASSIFICATIONS_PER_PAGE = 20

  def index
    @classifications = paginate_admin_relation(
      filtered_classifications.order(:name, :id),
      per_page: CLASSIFICATIONS_PER_PAGE
    ).to_a
  end

  def new
    @classification = Tag.new(active: true, color: "#e30613")
  end

  def create
    @classification = Tag.new(classification_params)

    if @classification.save
      redirect_to admin_classifications_path, notice: t("admin.flash.classification_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @classification = Tag.find(params[:id])
  end

  def update
    @classification = Tag.find(params[:id])

    if @classification.update(classification_params)
      redirect_to admin_classifications_path, notice: t("admin.flash.classification_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def filtered_classifications
    classifications = Tag.all
    classifications = classifications.where(active: true) if params[:status] == "active"
    classifications = classifications.where(active: false) if params[:status] == "disabled"

    if params[:q].present?
      query = "%#{params[:q].to_s.downcase}%"
      classifications = classifications.where("LOWER(name) LIKE ?", query)
    end

    classifications
  end

  def classification_params
    params.require(:tag).permit(:name, :color, :active)
  end
end
