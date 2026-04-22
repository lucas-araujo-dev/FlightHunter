require "rails_helper"

RSpec.describe "Searches", type: :request do
  let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

  before do
    post session_path, params: {email: user.email, password: "owner-password-123"}
  end

  describe "GET /searches/new (root)" do
    it "renders the search form" do
      get new_search_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("searches.new.title"))
    end

    it "is the root route" do
      get root_path
      expect(response.body).to include(I18n.t("searches.new.title"))
    end
  end

  describe "POST /searches" do
    let(:valid_params) do
      {
        origin_type: "airport", origin_code: "FOR",
        destination_type: "airport", destination_code: "GRU",
        trip_type: "one_way",
        departure_date_from: (Date.current + 10).to_s,
        departure_date_to: (Date.current + 20).to_s,
        cabin_class: "economy", passengers: 1
      }
    end

    it "stores params in session and redirects to new" do
      post searches_path, params: valid_params
      expect(response).to redirect_to(new_search_path)
      follow_redirect!
      expect(response.body).to include("FOR")
    end
  end

  it "redirects to login when logged out" do
    delete logout_path
    get root_path
    expect(response).to redirect_to(login_path)
  end
end
