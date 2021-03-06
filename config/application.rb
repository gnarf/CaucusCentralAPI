require File.expand_path('../boot', __FILE__)

require 'rails/all'

require 'csv'
require 'rack/throttle'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CaucusCentralAPI
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # Load services and serializers
    config.autoload_paths << Rails.root.join('app', 'serializers')
    config.autoload_paths << Rails.root.join('app', 'services')

    # Set default headers to allow cross-origin requests
    config.action_dispatch.default_headers.merge!('Access-Control-Allow-Origin' => '*')

    config.generators do |g|
      g.test_framework :rspec, fixture: true
      g.fixture_replacement :fabrication
      g.assets = false
      g.helper = false
    end

    config.middleware.use Rack::Throttle::Minute, max: 20

    config.middleware.insert_before 0, 'Rack::Cors' do
      allow do
        origins Rails.env.production? ? 'caucuscentral.berniesanders.com' : '*'
        resource '*', headers: :any, methods: [:get, :patch, :post, :delete, :options]
      end
    end
  end
end
