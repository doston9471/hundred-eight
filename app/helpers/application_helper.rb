# frozen_string_literal: true

require "digest"

module ApplicationHelper
  def current_room_player(room)
    return unless current_user

    room.room_players.find_by(user: current_user)
  end

  # Busts Turbo Frame cache when any seat's hand (or round state) changes. Must stay in sync
  # with anything that affects the per-user player panel.
  def room_player_panel_frame_src(room, round)
    return "#" unless round

    round.round_players.load
    sig = round.round_players.sort_by(&:id).map { |rp| "#{rp.id}:#{Array(rp.hand).join(',')};#{rp.updated_at.to_i}" }.join("|")
    sig += ";#{round.updated_at.to_i};#{round.current_turn_index};#{round.phase};#{round.required_suit};#{round.payload.to_json}"
    v = Digest::SHA256.hexdigest(sig)[0, 20]
    player_panel_room_path(room, round_id: round.id, v: v)
  end

  # Unicode suit symbols (card style) for legends and suit choice UI.
  def suit_glyph(suit)
    case suit.to_s
    when "hearts" then "♥"
    when "diamonds" then "♦"
    when "clubs" then "♣"
    when "spades" then "♠"
    else suit.to_s
    end
  end

  def suit_glyph_class(suit)
    case suit.to_s
    when "hearts" then "text-rose-400"
    when "diamonds" then "text-amber-300"
    when "clubs" then "text-emerald-400"
    when "spades" then "text-slate-300"
    else "text-white"
    end
  end
end
