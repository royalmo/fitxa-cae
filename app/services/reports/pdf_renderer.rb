module Reports
  class PdfRenderer
    DEFAULT_PDF_OPTIONS = {
      format: :A4,
      print_background: true,
      margin_top: 0.35,
      margin_bottom: 0.35,
      margin_left: 0.35,
      margin_right: 0.35
    }.freeze

    def self.render(template:, assigns:)
      html = ApplicationController.render(
        template: template,
        layout: "pdf",
        assigns: assigns
      )

      FerrumPdf.render_pdf(
        html: html,
        display_url: "http://fitxa-cae.local/",
        pdf_options: DEFAULT_PDF_OPTIONS
      )
    end
  end
end
