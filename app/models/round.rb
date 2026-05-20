# frozen_string_literal: true

class Round < ApplicationRecord
  PHASES = %w[normal eight_followup queen_pick_suit ace_tail seven_response].freeze

  enum :status, { in_progress: 0, completed: 1 }, prefix: true

  belongs_to :room
  belongs_to :winner, class_name: "RoomPlayer", optional: true

  has_many :round_players, dependent: :destroy
  has_many :card_plays, dependent: :destroy
  has_many :score_entries, dependent: :destroy

  validates :number, presence: true, uniqueness: { scope: :room_id }
  validates :phase, inclusion: { in: PHASES }

  def top_discard_code
    discard_pile.last
  end

  def current_turn_room_player_id
    turn_order[current_turn_index]
  end

  def out_room_player_ids
    Array((payload || {})["out_room_player_ids"]).map(&:to_s)
  end

  def round_winner_room_player_id
    (payload || {})["round_winner_room_player_id"]&.to_s
  end

  def player_out?(room_player_id)
    out_room_player_ids.include?(room_player_id.to_s)
  end

  def players_still_in_round_count
    turn_order.size - out_room_player_ids.size
  end

  def round_player_for(room_player)
    round_players.find_by!(room_player: room_player)
  end

  def seven_chain_sevens_count
    count = (payload || {})["seven_chain_sevens"].to_i
    count.positive? ? count : 1
  end

  def seven_response_penalty_draws
    2 * seven_chain_sevens_count
  end

  def payload_without_seven_chain
    (payload || {}).except("seven_chain_root_id", "seven_chain_source_id", "seven_chain_sevens")
  end

  def opening_seven_active?
    (payload || {})["opening_seven"] == true
  end

  def opening_starter_room_player_id
    turn_order.first&.to_s
  end

  # After the opening-seven responder completes their turn, the starter may play again.
  def clear_opening_seven_if_responded!(room_player)
    return unless opening_seven_active?
    return if room_player.id.to_s == opening_starter_room_player_id

    update!(payload: (payload || {}).except("opening_seven"))
  end

  def six_followup_continue?
    (payload || {})["six_followup_continue"] == true
  end

  def may_pass_without_drawing?
    pl = payload || {}
    if pl["six_followup_continue"]
      return true if pl["drew_from_deck_this_turn"].present?

      return !DrawCardService.draw_would_be_available?(self)
    end

    return true if pl["drew_from_deck_this_turn"].present?

    !DrawCardService.draw_would_be_available?(self)
  end
end
