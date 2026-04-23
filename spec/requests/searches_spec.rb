require "rails_helper"

RSpec.describe "Searches", type: :request do
  let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }
  let!(:for_airport) { create(:airport, iata_code: "FOR") }
  let!(:gru_airport) { create(:airport, :sao_paulo) }

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

    it "dispatches search and responds with turbo_stream + stream subscription on cache miss" do
      allow(FlightOffer::Search::Dispatch).to receive(:call).and_return(
        FlightOffer::Search::Dispatch::Result.new(status: :enqueued, offer_ids: nil)
      )

      post searches_path, params: valid_params, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="replace" target="search_results"')
      expect(response.body).to include("turbo-cable-stream-source")
    end

    it "renders cached offers inline on cache hit, without turbo-cable-stream-source" do
      offer = create(:flight_offer, origin_airport: for_airport, destination_airport: gru_airport)
      allow(FlightOffer::Search::Dispatch).to receive(:call).and_return(
        FlightOffer::Search::Dispatch::Result.new(status: :cache_hit, offer_ids: [offer.id])
      )

      post searches_path, params: valid_params, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream action="replace" target="search_results"')
      expect(response.body).not_to include("turbo-cable-stream-source")
      expect(response.body).to include(I18n.t("searches.cached_badge"))
      expect(response.body).to include("#{for_airport.iata_code} → #{gru_airport.iata_code}")
    end

    it "returns 422 and translated alert on invalid params" do
      post searches_path, params: valid_params.merge(origin_code: "XXX"), as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("searches.errors.origin_has_no_airports"))
    end

    it "re-renders new with flash.now on validation failure" do
      post searches_path, params: valid_params.merge(departure_date_from: "2020-01-01"), as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("searches.errors.departure_in_past"))
    end
  end

  it "redirects to login when logged out" do
    delete logout_path
    get root_path
    expect(response).to redirect_to(login_path)
  end
end
