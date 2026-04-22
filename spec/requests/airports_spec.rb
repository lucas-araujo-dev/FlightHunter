# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Airports autocomplete", type: :request do
  let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

  before do
    post session_path, params: {email: user.email, password: "owner-password-123"}
    create(:airport, iata_code: "FOR", name: "Pinto Martins", city: "Fortaleza", country: "BR")
    create(:airport, iata_code: "GRU", name: "Guarulhos", city: "São Paulo", country: "BR")
  end

  it "returns JSON with matching airports" do
    get airports_path, params: {q: "for"}
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to match(%r{application/json})
    json = JSON.parse(response.body)
    expect(json.first).to include("type" => "airport", "code" => "FOR")
  end

  it "returns empty array for short queries" do
    get airports_path, params: {q: "f"}
    expect(JSON.parse(response.body)).to eq([])
  end

  it "requires authentication" do
    delete logout_path
    get airports_path, params: {q: "for"}
    expect(response).to redirect_to(login_path)
  end
end
