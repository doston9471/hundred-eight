# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing", type: :system do
  it "shows title" do
    driven_by :rack_test
    visit root_path
    expect(page).to have_content("108")
  end
end
