require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "requires email" do
      user = User.new(password: "secret123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires unique email" do
      create(:user, email: "a@b.com")
      dupe = build(:user, email: "a@b.com")
      expect(dupe).not_to be_valid
      expect(dupe.errors[:email]).to include("has already been taken")
    end

    it "requires password on create" do
      user = User.new(email: "a@b.com")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end
  end

  describe "has_secure_password" do
    it "sets password_digest" do
      user = create(:user, password: "my-secret-123")
      expect(user.password_digest).to be_present
      expect(user.authenticate("my-secret-123")).to eq(user)
      expect(user.authenticate("wrong")).to eq(false)
    end
  end

  describe "#program_credentials" do
    it "persists encrypted JSON" do
      user = create(:user, program_credentials: {smiles: {login: "x", password: "y"}})
      user.reload
      expect(user.program_credentials).to eq({"smiles" => {"login" => "x", "password" => "y"}})
    end

    it "encrypts at rest" do
      user = create(:user, program_credentials: {smiles: {login: "x"}})
      raw = User.connection.select_value("SELECT program_credentials FROM users WHERE id = #{user.id}")
      expect(raw).not_to include("smiles")
      expect(raw).not_to include("login")
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
  end
end
