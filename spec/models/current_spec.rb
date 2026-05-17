# frozen_string_literal: true

require "rails_helper"

RSpec.describe Current, type: :model do
  it "delegates user from session" do
    user = create(:user)
    session = create(:session, user: user)
    described_class.session = session
    expect(described_class.user).to eq(user)
  ensure
    described_class.reset
  end

  it "returns nil user without a session" do
    described_class.session = nil
    expect(described_class.user).to be_nil
  ensure
    described_class.reset
  end
end
