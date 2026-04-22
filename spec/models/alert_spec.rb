require "rails_helper"

RSpec.describe Alert, type: :model do
  describe "validations" do
    it "requires user" do
      expect(build(:alert, user: nil)).not_to be_valid
    end

    it "requires origin + destination" do
      expect(build(:alert, origin_code: nil)).not_to be_valid
      expect(build(:alert, destination_code: nil)).not_to be_valid
    end

    it "requires at least one of max_price_cents or max_miles" do
      invalid = build(:alert, max_price_cents: nil, max_miles: nil)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:base]).to include(/preço ou milhas/i)
    end

    it "is valid with only max_price" do
      expect(build(:alert, max_price_cents: 80_000, max_miles: nil)).to be_valid
    end

    it "is valid with only max_miles" do
      expect(build(:alert, :miles_only)).to be_valid
    end

    it "round_trip requires return dates" do
      invalid = build(:alert, trip_type: "round_trip", return_date_from: nil, return_date_to: nil)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:return_date_from]).to be_present
    end

    it "one_way does not require return dates" do
      expect(build(:alert, trip_type: "one_way")).to be_valid
    end

    it "departure_date_to must be >= departure_date_from" do
      invalid = build(:alert, departure_date_from: 30.days.from_now, departure_date_to: 10.days.from_now)
      expect(invalid).not_to be_valid
    end

    it "rejects departure in the past" do
      invalid = build(:alert, departure_date_from: 1.day.ago)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:departure_date_from]).to be_present
    end

    it "limits to 10 active alerts per user" do
      user = create(:user)
      10.times { create(:alert, user: user, origin_code: "FOR", destination_code: "GRU") }
      eleventh = build(:alert, user: user)
      expect(eleventh).not_to be_valid
      expect(eleventh.errors[:base]).to include(/10 alerts/i)
    end

    it "allows more than 10 if some are paused" do
      user = create(:user)
      10.times { create(:alert, :paused, user: user) }
      active = build(:alert, user: user)
      expect(active).to be_valid
    end
  end

  describe "enums" do
    it "origin_type and destination_type accept airport|city" do
      %w[airport city].each do |t|
        expect(build(:alert, origin_type: t)).to be_valid
      end
    end

    it "trip_type accepts one_way|round_trip" do
      expect(build(:alert, trip_type: "one_way")).to be_valid
      expect(build(:alert, :round_trip)).to be_valid
    end
  end

  describe "scopes" do
    it ".active returns only active" do
      active = create(:alert)
      create(:alert, :paused)
      expect(Alert.active).to contain_exactly(active)
    end

    it ".due_for_check returns nil last_checked_at OR older than 2h" do
      never = create(:alert, last_checked_at: nil)
      stale = create(:alert, last_checked_at: 3.hours.ago)
      fresh = create(:alert, last_checked_at: 30.minutes.ago)
      expect(Alert.due_for_check).to contain_exactly(never, stale)
      expect(Alert.due_for_check).not_to include(fresh)
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:alert_matches).dependent(:destroy) }
    it { is_expected.to have_many(:flight_offers).through(:alert_matches) }
  end
end
