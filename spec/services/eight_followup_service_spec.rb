# frozen_string_literal: true

require "rails_helper"

RSpec.describe EightFollowupService, type: :service do
  describe ".continues_chain?" do
    it "is true only for eights" do
      expect(described_class.continues_chain?("8|hearts")).to be true
      expect(described_class.continues_chain?("10|hearts")).to be false
    end
  end
end
