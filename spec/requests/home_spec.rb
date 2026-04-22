require "rails_helper"

RSpec.describe "Home", type: :request do
  let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

  it "redirects to login when logged out" do
    get root_path
    expect(response).to redirect_to(login_path)
  end

  it "renders the home page when logged in" do
    post session_path, params: {email: user.email, password: "owner-password-123"}
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("FlightHunter")
    expect(response.body).to include(user.email)
  end
end
