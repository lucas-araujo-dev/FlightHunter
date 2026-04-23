require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec/cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }

  {
    "DUFFEL_API_KEY" => -> { Rails.application.credentials.dig(:duffel, :api_key).to_s },
    "AMADEUS_CLIENT_ID" => -> { Rails.application.credentials.dig(:amadeus, :client_id).to_s },
    "AMADEUS_CLIENT_SECRET" => -> { Rails.application.credentials.dig(:amadeus, :client_secret).to_s },
    "SEATS_AERO_API_KEY" => -> { Rails.application.credentials.dig(:seats_aero, :api_key).to_s },
    "TELEGRAM_BOT_TOKEN" => -> { Rails.application.credentials.dig(:telegram, :bot_token).to_s },
    "TELEGRAM_OWNER_CHAT_ID" => -> { Rails.application.credentials.dig(:telegram, :owner_chat_id).to_s },
    "SENTRY_DSN" => -> { Rails.application.credentials.dig(:sentry_dsn).to_s }
  }.each do |placeholder, resolver|
    config.filter_sensitive_data("<#{placeholder}>") { resolver.call }
  end
end

WebMock.disable_net_connect!(allow_localhost: true)
