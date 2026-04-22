require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec/cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [ :method, :uri, :body ]
  }

  %w[
    duffel_api_key
    amadeus_client_id
    amadeus_client_secret
    seats_aero_api_key
    telegram_bot_token
    telegram_owner_chat_id
    sentry_dsn
  ].each do |secret|
    config.filter_sensitive_data("<#{secret.upcase}>") do
      Rails.application.credentials.dig(secret.to_sym).to_s
    end
  end
end

WebMock.disable_net_connect!(allow_localhost: true)
