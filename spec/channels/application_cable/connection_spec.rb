# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }
  let!(:session) { user.sessions.create!(ip_address: "127.0.0.1", user_agent: "RSpec") }

  it "connects when a valid session cookie is present" do
    cookies.signed[:session_id] = session.id

    connect

    expect(connection.current_user).to eq(user)
  end

  it "rejects the connection without a session cookie" do
    expect { connect }.to have_rejected_connection
  end
end
