require "base64"

module Admin::ReportsHelper
  def admin_reports_month_options
    I18n.t("date.month_names").each_with_index.filter_map do |month_name, month_number|
      [ month_name, month_number ] if month_number.positive?
    end
  end

  def pdf_brand_logo
    text_suffix = app_brand_suffix_image_asset.blank? && app_brand_suffix.present?

    tag.div(class: class_names("report-logo", "report-logo-with-text-suffix": text_suffix), aria: { label: app_name }) do
      brand_parts = [ tag.span(app_brand_prefix, class: "report-logo-fitxa") ]

      if app_brand_suffix_image_asset.present?
        brand_parts << tag.img(src: pdf_brand_logo_image_src, alt: app_brand_suffix, class: "report-logo-image")
      elsif app_brand_suffix.present?
        brand_parts << tag.span(app_brand_suffix, class: "report-logo-text-suffix")
      end

      safe_join(brand_parts)
    end
  end

  def pdf_month_year_title(date)
    l(date, format: t("admin.reports.pdf.month_year_format")).sub(/\A./) { |character| character.upcase }
  end

  private

  def pdf_brand_logo_image_src
    @pdf_brand_logo_image_src ||= begin
      image_path = Rails.root.join("app/assets/images", app_brand_suffix_image_asset)
      "data:image/png;base64,#{Base64.strict_encode64(image_path.binread)}"
    end
  end
end
