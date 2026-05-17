# frozen_string_literal: true

class InitialSchema < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :username, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :avatar_url
      t.timestamps
    end
    add_index :users, :username, unique: true
    add_index :users, :email, unique: true

    create_table :sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    create_table :rooms, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :host, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.string :name
      t.integer :status, null: false, default: 0
      t.timestamps
    end
    add_index :rooms, :status

    create_table :room_players, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :room, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.integer :seat, null: false
      t.boolean :eliminated, null: false, default: false
      t.integer :total_score, null: false, default: 0
      t.boolean :online, null: false, default: false
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :room_players, [ :room_id, :user_id ], unique: true
    add_index :room_players, [ :room_id, :seat ], unique: true

    create_table :invite_tokens, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :room, null: false, foreign_key: true, type: :uuid
      t.string :token_digest, null: false
      t.datetime :expires_at
      t.timestamps
    end
    add_index :invite_tokens, :token_digest, unique: true

    create_table :rounds, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :room, null: false, foreign_key: true, type: :uuid
      t.integer :number, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.jsonb :draw_pile, null: false, default: []
      t.jsonb :discard_pile, null: false, default: []
      t.jsonb :turn_order, null: false, default: []
      t.integer :current_turn_index, null: false, default: 0
      t.string :phase, null: false, default: "normal"
      t.string :required_suit
      t.references :winner, foreign_key: { to_table: :room_players }, type: :uuid
      t.timestamps
    end
    add_index :rounds, [ :room_id, :number ], unique: true
    add_index :rounds, :status

    create_table :round_players, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :round, null: false, foreign_key: true, type: :uuid
      t.references :room_player, null: false, foreign_key: true, type: :uuid
      t.jsonb :hand, null: false, default: []
      t.timestamps
    end
    add_index :round_players, [ :round_id, :room_player_id ], unique: true

    create_table :card_plays, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :round, null: false, foreign_key: true, type: :uuid
      t.references :round_player, null: false, foreign_key: true, type: :uuid
      t.integer :kind, null: false, default: 0
      t.string :card_code
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    create_table :score_entries, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :round, null: false, foreign_key: true, type: :uuid
      t.references :room_player, null: false, foreign_key: true, type: :uuid
      t.integer :points, null: false, default: 0
      t.integer :bonus_points, null: false, default: 0
      t.timestamps
    end
    add_index :score_entries, [ :round_id, :room_player_id ], unique: true
  end
end
