# frozen_string_literal: true

class RoundMetadataAndRoomLastLoser < ActiveRecord::Migration[8.1]
  def change
    add_column :rounds, :payload, :jsonb, default: {}, null: false
    add_column :rooms, :last_round_loser_room_player_id, :uuid
    add_foreign_key :rooms, :room_players, column: :last_round_loser_room_player_id, on_delete: :nullify
  end
end
