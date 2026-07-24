module AdminPagination
  extend ActiveSupport::Concern

  DEFAULT_ADMIN_PER_PAGE = 20

  private

  def paginate_admin_relation(relation, per_page: DEFAULT_ADMIN_PER_PAGE)
    @admin_records_count = relation.count
    @admin_total_pages = [ (@admin_records_count.to_f / per_page).ceil, 1 ].max
    @admin_page = [ requested_admin_page, @admin_total_pages ].min
    @admin_previous_page = @admin_page - 1 if @admin_page > 1
    @admin_next_page = @admin_page + 1 if @admin_page < @admin_total_pages
    @admin_records_range_start = ((@admin_page - 1) * per_page) + 1 if @admin_records_count.positive?

    records = relation.offset((@admin_page - 1) * per_page).limit(per_page)
    @admin_records_range_end = @admin_records_range_start + records.size - 1 if @admin_records_range_start
    records
  end

  def requested_admin_page
    page = Integer(params[:page], exception: false)

    page&.positive? ? page : 1
  end
end
