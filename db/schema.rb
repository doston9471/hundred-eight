# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_15_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "card_plays", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "card_code"
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.uuid "round_id", null: false
    t.uuid "round_player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["round_id"], name: "index_card_plays_on_round_id"
    t.index ["round_player_id"], name: "index_card_plays_on_round_player_id"
  end

  create_table "invite_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.uuid "room_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_invite_tokens_on_room_id"
    t.index ["token_digest"], name: "index_invite_tokens_on_token_digest", unique: true
  end

  create_table "room_players", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "eliminated", default: false, null: false
    t.datetime "last_seen_at"
    t.boolean "online", default: false, null: false
    t.uuid "room_id", null: false
    t.integer "seat", null: false
    t.integer "total_score", default: 0, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["room_id", "seat"], name: "index_room_players_on_room_id_and_seat", unique: true
    t.index ["room_id", "user_id"], name: "index_room_players_on_room_id_and_user_id", unique: true
    t.index ["room_id"], name: "index_room_players_on_room_id"
    t.index ["user_id"], name: "index_room_players_on_user_id"
  end

  create_table "rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "host_id", null: false
    t.uuid "last_round_loser_room_player_id"
    t.string "name"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["host_id"], name: "index_rooms_on_host_id"
    t.index ["status"], name: "index_rooms_on_status"
  end

  create_table "round_players", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "hand", default: [], null: false
    t.uuid "room_player_id", null: false
    t.uuid "round_id", null: false
    t.datetime "updated_at", null: false
    t.index ["room_player_id"], name: "index_round_players_on_room_player_id"
    t.index ["round_id", "room_player_id"], name: "index_round_players_on_round_id_and_room_player_id", unique: true
    t.index ["round_id"], name: "index_round_players_on_round_id"
  end

  create_table "rounds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_turn_index", default: 0, null: false
    t.jsonb "discard_pile", default: [], null: false
    t.jsonb "draw_pile", default: [], null: false
    t.jsonb "final_hands", default: {}, null: false
    t.integer "number", default: 1, null: false
    t.jsonb "payload", default: {}, null: false
    t.string "phase", default: "normal", null: false
    t.string "required_suit"
    t.uuid "room_id", null: false
    t.jsonb "scoring_summary", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.jsonb "turn_order", default: [], null: false
    t.datetime "updated_at", null: false
    t.uuid "winner_id"
    t.index ["room_id", "number"], name: "index_rounds_on_room_id_and_number", unique: true
    t.index ["room_id"], name: "index_rounds_on_room_id"
    t.index ["status"], name: "index_rounds_on_status"
    t.index ["winner_id"], name: "index_rounds_on_winner_id"
  end

  create_table "score_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "bonus_points", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "points", default: 0, null: false
    t.uuid "room_player_id", null: false
    t.uuid "round_id", null: false
    t.datetime "updated_at", null: false
    t.index ["room_player_id"], name: "index_score_entries_on_room_player_id"
    t.index ["round_id", "room_player_id"], name: "index_score_entries_on_round_id_and_room_player_id", unique: true
    t.index ["round_id"], name: "index_score_entries_on_round_id"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "card_plays", "round_players"
  add_foreign_key "card_plays", "rounds"
  add_foreign_key "invite_tokens", "rooms"
  add_foreign_key "room_players", "rooms"
  add_foreign_key "room_players", "users"
  add_foreign_key "rooms", "room_players", column: "last_round_loser_room_player_id", on_delete: :nullify
  add_foreign_key "rooms", "users", column: "host_id"
  add_foreign_key "round_players", "room_players"
  add_foreign_key "round_players", "rounds"
  add_foreign_key "rounds", "room_players", column: "winner_id"
  add_foreign_key "rounds", "rooms"
  add_foreign_key "score_entries", "room_players"
  add_foreign_key "score_entries", "rounds"
  add_foreign_key "sessions", "users"
end
