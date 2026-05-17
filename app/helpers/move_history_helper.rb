# frozen_string_literal: true

module MoveHistoryHelper
  include CardsHelper

  def card_play_description(card_play)
    user = card_play.round_player.room_player.user.username
    meta = card_play.metadata || {}
    reason = meta["reason"].to_s

    case card_play.kind
    when "play"
      label = card_short_label(card_play.card_code)
      top = meta["top_code"]
      if top.present?
        "#{user} played #{label} on #{card_short_label(top)}"
      else
        "#{user} played #{label}"
      end
    when "suit_choice"
      suit = meta["suit"].to_s
      if suit.present? && (glyph = SUIT_GLYPH[suit])
        "#{user} chose #{glyph} (#{suit})"
      else
        "#{user} chose #{suit.presence || 'a suit'}"
      end
    when "pass"
      case reason
      when "round_opening"
        round_start_description(meta, starter_username: user)
      when "seven_take", "seven_stack", "opening_seven", "six"
        count = meta["count"].to_i
        "#{user} took #{count} #{'card'.pluralize(count)}"
      else
        "#{user} passed"
      end
    else
      "#{user} moved"
    end
  end

  def round_start_header(round)
    play = round_opening_play(round)

    if play
      round_start_description(
        play.metadata,
        starter_username: play.round_player.room_player.user.username
      )
    else
      round_start_description_from_round(round)
    end
  end

  def round_history_plays(round, chronological: false, limit: 200)
    scope = round.card_plays.for_history
      .includes(round_player: { room_player: :user })
      .where("COALESCE(card_plays.metadata->>'reason', '') <> ?", "round_opening")

    chronological ? scope.order(created_at: :asc).limit(limit) : scope.order(created_at: :desc).limit(limit)
  end

  private

  def round_opening_play(round)
    round.card_plays.where(kind: :pass).includes(round_player: { room_player: :user }).find do |cp|
      cp.metadata&.dig("reason") == "round_opening"
    end
  end

  def round_start_description(meta, starter_username:)
    center = card_short_label(meta["center_code"])
    first_turn_id = meta["first_turn_room_player_id"].to_s
    starter_id = meta["starter_room_player_id"].to_s

    text = "#{starter_username} starts — center: #{center}"

    if first_turn_id.present? && starter_id.present? && first_turn_id != starter_id
      first_name = username_for_room_player(first_turn_id)
      text += ". #{first_name} plays first" if first_name
    end

    text
  end

  def round_start_description_from_round(round)
    starter_id = round.turn_order.first&.to_s
    return nil unless starter_id

    starter_rp = round.round_players.includes(room_player: :user).find_by(room_player_id: starter_id)
    return nil unless starter_rp

    center_code = round.discard_pile.first
    return nil unless center_code

    meta = {
      "center_code" => center_code,
      "first_turn_room_player_id" => round.turn_order[round.current_turn_index].to_s,
      "starter_room_player_id" => starter_id
    }
    round_start_description(meta, starter_username: starter_rp.room_player.user.username)
  end

  def username_for_room_player(room_player_id)
    RoomPlayer.includes(:user).find_by(id: room_player_id)&.user&.username
  end
end
