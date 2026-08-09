class ApplicationMailer < ActionMailer::Base
  self.delivery_job = ApplicationMailDeliveryJob

  default from: -> { Rails.configuration.x.mailer_from_email },
    reply_to: -> { Rails.configuration.x.mailer_reply_to_email }
  layout "mailer"

  helper_method :app_admin_name,
    :app_brand_prefix,
    :app_brand_suffix,
    :app_name,
    :mailer_app_url,
    :mailer_logo_url

  def app_name
    Rails.configuration.x.app_name
  end

  def app_admin_name
    "#{app_name} Admin"
  end

  def app_brand_prefix
    app_name.start_with?("Fitxa") ? "Fitxa" : app_name
  end

  def app_brand_suffix
    return unless app_name.start_with?("Fitxa")

    app_name.delete_prefix("Fitxa").presence
  end

  private

  def mailer_app_url
    root_url
  end

  def mailer_logo_url
    asset = app_brand_suffix_image_asset
    return unless asset

    return asset if asset.to_s.start_with?("http://", "https://", "//")

    attachments.inline[asset] ||= Rails.root.join("app/assets/images", asset).read
    attachments[asset].url
  end

  def app_brand_suffix_image_asset
    Rails.configuration.x.app_brand_suffix_image
  end
end
