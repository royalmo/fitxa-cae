require "base64"

module Admin::ReportsHelper
  def admin_reports_month_options
    I18n.t("date.month_names").each_with_index.filter_map do |month_name, month_number|
      [ month_name, month_number ] if month_number.positive?
    end
  end

  def pdf_brand_logo
    tag.div(class: "report-logo", aria: { label: t("app.name") }) do
      safe_join([
        tag.span(t("app.short_name"), class: "report-logo-fitxa"),
        tag.img(src: pdf_brand_logo_image_src, alt: "CAE", class: "report-logo-image")
      ])
    end
  end

  def pdf_month_year_title(date)
    l(date, format: t("admin.reports.pdf.month_year_format")).sub(/\A./) { |character| character.upcase }
  end

  private

  def pdf_brand_logo_image_src
    @pdf_brand_logo_image_src ||= begin
      image_path = Rails.root.join("app/assets/images/cae_logo_trimmed.png")
      "data:image/png;base64,#{Base64.strict_encode64(image_path.binread)}"
    end
  end
end
