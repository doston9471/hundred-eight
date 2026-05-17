# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication", type: :request do
  describe "registration" do
    it "creates an account and signs the user in" do
      expect {
        post registration_path, params: {
          user: {
            username: "newbie",
            email: "newbie@example.test",
            password: "password12",
            password_confirmation: "password12"
          }
        }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(rooms_path)
      user = User.find_by!(email: "newbie@example.test")
      expect(Session.where(user: user)).to exist
    end

    it "re-renders the form when validation fails" do
      post registration_path, params: {
        user: {
          username: "",
          email: "bad",
          password: "short",
          password_confirmation: "short"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Sign up")
    end
  end

  describe "session" do
    let(:user) { create(:user) }

    it "signs in with valid credentials" do
      post session_path, params: { email: user.email, password: "password12" }
      expect(response).to be_redirect
      expect(Session.where(user: user)).to exist
    end

    it "rejects invalid credentials" do
      post session_path, params: { email: user.email, password: "wrong" }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include("Try another email")
    end

    it "signs out" do
      post session_path, params: { email: user.email, password: "password12" }
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "password reset" do
    let(:user) { create(:user) }

    it "accepts a reset request and redirects with a notice" do
      expect {
        post passwords_path, params: { email: user.email }
      }.to have_enqueued_mail(PasswordsMailer, :reset)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:notice]).to include("Password reset instructions sent")
    end

    it "does not reveal whether the email exists" do
      post passwords_path, params: { email: "missing@example.test" }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:notice]).to include("Password reset instructions sent")
    end

    it "resets the password with a valid token" do
      token = user.password_reset_token
      patch password_path(token), params: { password: "newpassword12", password_confirmation: "newpassword12" }

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate("newpassword12")).to be_truthy
    end

    it "rejects an invalid reset token" do
      get edit_password_path("invalid-token")
      expect(response).to redirect_to(new_password_path)
      expect(flash[:alert]).to include("invalid or has expired")
    end
  end
end
