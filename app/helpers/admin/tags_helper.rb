module Admin::TagsHelper
  TAG_BACKGROUND_FALLBACK = "#6b7280"
  TAG_DARK_TEXT_COLOR = "#111827"
  TAG_LIGHT_TEXT_COLOR = "#ffffff"

  def admin_tag_status(tag)
    tag.active? ? :active : :disabled
  end

  def admin_tag_status_text(status)
    t("admin.tags.statuses.#{status}", default: status_text(status))
  end

  def admin_tag_status_icon(status)
    status.to_sym == :active ? "circle-check" : "circle-off"
  end

  def admin_tag_status_class(status)
    class_names(
      "admin-tag-status",
      "is-active": status.to_sym == :active,
      "is-inactive": status.to_sym == :disabled
    )
  end

  def admin_tag_activation_action(tag)
    tag.active? ? :deactivate : :activate
  end

  def admin_tag_activation_icon(tag)
    tag.active? ? "circle-off" : "circle-check"
  end

  def admin_tag_activation_modal_id(tag)
    "tag_activation_modal_#{tag.id}"
  end

  def admin_tag_activation_button_class(tag)
    class_names(
      "btn btn-sm admin-row-action",
      tag.active? ? "btn-outline-secondary" : "btn-outline-success"
    )
  end

  def admin_tag_activation_submit_class(action)
    class_names("btn", action.to_sym == :deactivate ? "btn-danger" : "btn-primary")
  end

  def admin_tag_form_modal_id(tag)
    tag.persisted? ? "tag_form_modal_#{tag.id}" : "tag_form_modal_new"
  end

  def admin_tag_form_title(tag)
    t(tag.persisted? ? "admin.tags.form.edit_title" : "admin.tags.form.new_title")
  end

  def admin_tag_form_url(tag)
    tag.persisted? ? admin_tag_path(tag) : admin_tags_path
  end

  def admin_tag_form_method(tag)
    tag.persisted? ? :patch : :post
  end

  def admin_tag_employees_count(tag, counts_by_tag_id)
    counts_by_tag_id.fetch(tag.id, 0)
  end

  def admin_tag_employees_count_label(tag, count)
    t("admin.tags.index.employees_count", count: count, name: tag.name)
  end

  def admin_tag_name_style(tag)
    background_color = admin_tag_background_color(tag.color)

    "--admin-tag-bg: #{background_color}; --admin-tag-color: #{admin_tag_text_color(background_color)};"
  end

  private

  def admin_tag_background_color(color)
    normalized_color = color.to_s.strip

    return normalized_color.downcase if normalized_color.match?(/\A#[0-9a-fA-F]{6}\z/)

    TAG_BACKGROUND_FALLBACK
  end

  def admin_tag_text_color(background_color)
    background_channels = hex_color_channels(background_color)
    dark_contrast = contrast_ratio(background_channels, hex_color_channels(TAG_DARK_TEXT_COLOR))
    light_contrast = contrast_ratio(background_channels, hex_color_channels(TAG_LIGHT_TEXT_COLOR))

    dark_contrast >= light_contrast ? TAG_DARK_TEXT_COLOR : TAG_LIGHT_TEXT_COLOR
  end

  def hex_color_channels(color)
    color.delete_prefix("#").scan(/../).map { |component| component.to_i(16) }
  end

  def contrast_ratio(first_color_channels, second_color_channels)
    first_luminance = relative_luminance(first_color_channels)
    second_luminance = relative_luminance(second_color_channels)
    lighter_luminance, darker_luminance = [ first_luminance, second_luminance ].sort.reverse

    (lighter_luminance + 0.05) / (darker_luminance + 0.05)
  end

  def relative_luminance(color_channels)
    red, green, blue = color_channels.map { |channel| linear_rgb_channel(channel) }

    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  end

  def linear_rgb_channel(channel)
    scaled_channel = channel / 255.0

    return scaled_channel / 12.92 if scaled_channel <= 0.03928

    ((scaled_channel + 0.055) / 1.055) ** 2.4
  end
end
