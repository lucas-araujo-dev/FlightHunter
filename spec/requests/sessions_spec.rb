require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user, email: "owner@flighthunter.local", password: "owner-password-123") }

  describe "GET /login" do
    it "renders the login form when logged out" do
      get login_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Entrar no FlightHunter")
    end

    it "redirects to root when already logged in" do
      post session_path, params: {email: user.email, password: "owner-password-123"}
      get login_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    it "logs in with valid credentials" do
      post session_path, params: {email: user.email, password: "owner-password-123"}
      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to eq(user.id)
    end

    it "is case-insensitive for email" do
      post session_path, params: {email: user.email.upcase, password: "owner-password-123"}
      expect(response).to redirect_to(root_path)
    end

    it "rejects wrong password" do
      post session_path, params: {email: user.email, password: "wrong"}
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Email ou senha inválidos.")
    end

    it "rejects unknown email" do
      post session_path, params: {email: "nobody@nowhere.com", password: "secret"}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /logout" do
    it "clears session and redirects to login" do
      post session_path, params: {email: user.email, password: "owner-password-123"}
      delete logout_path
      expect(response).to redirect_to(login_path)
      expect(session[:user_id]).to be_nil
    end
  end
end
