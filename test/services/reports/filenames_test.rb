require "test_helper"

class Reports::FilenamesTest < ActiveSupport::TestCase
  test "uses runtime app slug for company-level exports" do
    period_start = Date.new(2026, 7, 1)
    tag = Tag.new(name: "Obra Nord")

    with_app_brand(name: "FitxaXarranca", slug: "fitxa-xarranca") do
      assert_equal "fitxa-xarranca-obra-nord-2026-07.zip", Reports::Filenames.tag_zip(tag, period_start)
      assert_equal "fitxa-xarranca-empresa-2026-07.zip", Reports::Filenames.company_zip(period_start)
      assert_equal "fitxa-xarranca-resum-mensual-2026-07.pdf", Reports::Filenames.monthly_summary_pdf(period_start)
      assert_equal "fitxa-xarranca-resum-mensual-2026-07.csv", Reports::Filenames.monthly_summary_csv(period_start)
    end
  end
end
