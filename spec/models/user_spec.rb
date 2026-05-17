# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "requires unique email and username" do
    create(:user, email: "a@a.com", username: "alice")
    dup = build(:user, email: "a@a.com", username: "bob")
    expect(dup).not_to be_valid
  end

  it "normalizes email" do
    user = create(:user, email: "  MIXED@Example.COM  ")
    expect(user.reload.email).to eq("mixed@example.com")
  end

  it "allows nil password on update" do
    user = create(:user)
    user.username = "newname"
    expect(user).to be_valid
  end

  it "requires minimum password length on create" do
    user = build(:user, password: "short", password_confirmation: "short")
    expect(user).not_to be_valid
  end
end
