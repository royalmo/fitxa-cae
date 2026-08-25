module MailerHelper
  LOGO_HEIGHT = 30
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

  MAILER_STYLES = {
    body: "margin: 0; padding: 0; background: #f5f5f5; color: #141414; font-family: Arial, Helvetica, sans-serif; line-height: 1.5;",
    link: "color: #b90510;",
    shell: "box-sizing: border-box; width: 100%; padding: 28px 12px; background: #f5f5f5;",
    panel: "box-sizing: border-box; width: 100%; max-width: 640px; margin: 0 auto; background: #ffffff; border: 1px solid #e1e1e1;",
    header: "box-sizing: border-box; padding: 24px; border-bottom: 4px solid #e30613; text-align: center;",
    content: "box-sizing: border-box; padding: 24px;",
    brand: "display: inline-block; color: #e30613; font-size: 22px; font-weight: 700; line-height: 1; text-decoration: none;",
    brand_part: "color: #e30613; font-size: 22px; font-weight: 900; line-height: 1;",
    logo: "display: inline-block; margin-left: 2px; vertical-align: middle; border: 0; outline: none; text-decoration: none;",
    paragraph: "margin: 0 0 16px;",
    code_wrap: "margin: 0 0 16px; text-align: center;",
    code: "display: inline-block; margin: 6px 0 18px; padding: 10px 14px; background: #fff4f5; border: 0; border-radius: 3px; color: #141414; font-size: 28px; font-weight: 700; letter-spacing: 0; text-align: center;",
    button_wrap: "margin: 0 0 16px; text-align: center;",
    button: "display: inline-block; margin: 0 auto; padding: 10px 14px; background: #e30613; color: #ffffff; text-decoration: none;",
    help: "margin: 0 0 16px; color: #555555; font-size: 13px;",
    fallback_link: "color: #b90510; overflow-wrap: anywhere; word-break: break-word;",
    details: "margin: 0 0 18px;",
    details_term: "margin-top: 10px; color: #555555; font-size: 13px; font-weight: 700;",
    details_description: "margin: 2px 0 0;"
  }.freeze

  def mailer_style(name)
    MAILER_STYLES.fetch(name)
  end

  def mailer_logo_dimensions
    intrinsic_width, intrinsic_height = png_dimensions(Rails.configuration.x.app_brand_suffix_image)
    return { height: LOGO_HEIGHT } unless intrinsic_width && intrinsic_height&.positive?

    {
      width: (intrinsic_width.to_f / intrinsic_height * LOGO_HEIGHT).round,
      height: LOGO_HEIGHT
    }
  end

  private

  def png_dimensions(asset)
    return if asset.blank? || asset.to_s.start_with?("/", "http://", "https://", "//")

    image_path = Rails.root.join("app/assets/images", asset)
    return unless image_path.file?

    header = image_path.binread(24)
    return unless header.bytesize >= 24 && header.byteslice(0, 8) == PNG_SIGNATURE

    header.byteslice(16, 8).unpack("NN")
  end
end
