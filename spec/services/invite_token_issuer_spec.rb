# frozen_string_literal: true

require "rails_helper"

RSpec.describe InviteTokenIssuer, type: :service do
  let(:room) { create(:room) }

  it "persists a digest and returns the raw secret" do
    raw = described_class.call!(room: room)
    expect(raw).to be_present
    token = room.invite_tokens.last!
    expect(token.token_digest).to eq(InviteToken.digest(raw))
    expect(token.expires_at).to be_within(2.seconds).of(7.days.from_now)
  end
end
