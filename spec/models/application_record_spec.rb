# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationRecord, type: :model do
  it "is configured as the abstract base class" do
    expect(described_class).to be < ActiveRecord::Base
    expect(described_class.abstract_class?).to be true
  end
end
