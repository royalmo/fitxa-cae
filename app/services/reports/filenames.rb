module Reports
  module Filenames
    module_function

    def employee_pdf(employee, period_start)
      "#{slug(employee.full_name.presence || I18n.t("admin.reports.exports.filenames.employee_fallback", id: employee.id))}-#{period(period_start)}.pdf"
    end

    def tag_zip(tag, period_start)
      "#{app_slug}-#{slug(tag.name)}-#{period(period_start)}.zip"
    end

    def company_zip(period_start)
      I18n.t("admin.reports.exports.filenames.company_zip", app_slug: app_slug, period: period(period_start))
    end

    def monthly_summary_pdf(period_start)
      I18n.t("admin.reports.exports.filenames.monthly_summary_pdf", app_slug: app_slug, period: period(period_start))
    end

    def monthly_summary_csv(period_start)
      I18n.t("admin.reports.exports.filenames.monthly_summary_csv", app_slug: app_slug, period: period(period_start))
    end

    def app_slug
      Rails.configuration.x.app_slug
    end

    def slug(value)
      I18n.transliterate(value.to_s)
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/\A-|-+\z/, "")
        .presence || I18n.t("admin.reports.exports.filenames.empty_slug")
    end

    def period(period_start)
      period_start.strftime("%Y-%m")
    end
  end
end
