# frozen_string_literal: true

class RoundFinalHandsAndCardPlayPass < ActiveRecord::Migration[8.1]
  def change
    add_column :rounds, :final_hands, :jsonb, null: false, default: {}
    add_column :rounds, :scoring_summary, :jsonb, null: false, default: {}
  end
end
