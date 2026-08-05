module Reports
  module Filenames
    module_function

    def employee_pdf(employee, period_start)
      "#{slug(employee.full_name.presence || "persona-#{employee.id}")}-#{period_start.strftime("%Y-%m")}.pdf"
    end

    def tag_zip(tag, period_start)
      "fitxa-cae-#{slug(tag.name)}-#{period_start.strftime("%Y-%m")}.zip"
    end

    def company_zip(period_start)
      "fitxa-cae-empresa-#{period_start.strftime("%Y-%m")}.zip"
    end

    def monthly_summary_pdf(period_start)
      "fitxa-cae-resum-mensual-#{period_start.strftime("%Y-%m")}.pdf"
    end

    def monthly_summary_csv(period_start)
      "fitxa-cae-resum-mensual-#{period_start.strftime("%Y-%m")}.csv"
    end

    def slug(value)
      I18n.transliterate(value.to_s)
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/\A-|-+\z/, "")
        .presence || "informe"
    end
  end
end
