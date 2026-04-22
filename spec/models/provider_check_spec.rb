require "rails_helper"

RSpec.describe ProviderCheck, type: :model do
  describe "validations" do
    it "requires provider" do
      expect(build(:provider_check, provider: nil)).not_to be_valid
    end

    it "requires status" do
      expect(build(:provider_check, status: nil)).not_to be_valid
    end

    it "requires ran_at" do
      expect(build(:provider_check, ran_at: nil)).not_to be_valid
    end
  end

  describe "enums" do
    it "accepts success|failure|rate_limited" do
      expect(build(:provider_check, status: "success")).to be_valid
      expect(build(:provider_check, :failed)).to be_valid
      expect(build(:provider_check, :rate_limited)).to be_valid
    end

    it "rejects invalid status" do
      expect { build(:provider_check, status: "meh") }.to raise_error(ArgumentError)
    end
  end

  describe "scopes" do
    it ".recent orders by ran_at desc" do
      old = create(:provider_check, ran_at: 2.hours.ago)
      new = create(:provider_check, ran_at: 10.minutes.ago)
      expect(ProviderCheck.recent.first).to eq(new)
      expect(ProviderCheck.recent.last).to eq(old)
    end

    it ".for_provider filters by provider" do
      duffel = create(:provider_check, provider: "duffel")
      create(:provider_check, provider: "amadeus")
      expect(ProviderCheck.for_provider("duffel")).to contain_exactly(duffel)
    end

    it ".failed returns non-success" do
      create(:provider_check)
      failed = create(:provider_check, :failed)
      expect(ProviderCheck.failed).to contain_exactly(failed)
    end
  end
end
