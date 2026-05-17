# frozen_string_literal: true

require "rails_helper"

RSpec.describe Session, type: :model do
  it "belongs to a user" do
    session = create(:session)
    expect(session.user).to be_present
  end
end
