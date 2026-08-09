require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FitxaCae
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Europe/Madrid"
    config.i18n.default_locale = :ca
    config.i18n.available_locales = [ :ca ]
    config.exceptions_app = ->(env) do
      Rails.application.routes.call(env)
    rescue StandardError
      ActionDispatch::PublicExceptions.new(Rails.public_path).call(env)
    end
    config.x.app_version = "1.0"
    config.x.app_name = ENV.fetch("APP_NAME", "FitxaCAE")
    config.x.app_slug = ENV.fetch("APP_SLUG", "fitxa-cae")
    config.x.human_resources_email = ENV.fetch("HUMAN_RESOURCES_EMAIL", "rrhh@cae.cat")
    config.x.legal_notice_url = ENV.fetch("LEGAL_NOTICE_URL", "https://cae.cat/avisos-legals/")
    config.x.mailer_from_email = ENV.fetch("MAILER_FROM_EMAIL", "from@example.com")
    config.x.mailer_reply_to_email = ENV.fetch("MAILER_REPLY_TO_EMAIL", config.x.human_resources_email)
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
