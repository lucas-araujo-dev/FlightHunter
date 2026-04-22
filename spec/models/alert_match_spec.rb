require "rails_helper"

RSpec.describe AlertMatch, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:alert) }
    it { is_expected.to belong_to(:flight_offer) }
  end

  describe "validations" do
    it "prevents duplicate alert + flight_offer pair" do
      match = create(:alert_match)
      dupe = build(:alert_match, alert: match.alert, flight_offer: match.flight_offer)
      expect(dupe).not_to be_valid
    end
  end

  describe "scopes" do
    it ".pending returns matches without notified_at" do
      pending = create(:alert_match)
      create(:alert_match, :notified)
      expect(AlertMatch.pending).to contain_exactly(pending)
    end

    it ".notified returns matches with notified_at" do
      notified = create(:alert_match, :notified)
      create(:alert_match)
      expect(AlertMatch.notified).to contain_exactly(notified)
    end
  end
end
