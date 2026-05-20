# frozen_string_literal: true

module TurnManager
  module_function

  def previous_room_player_id(round)
    order = round.turn_order
    n = order.size
    return nil if n.zero?

    out = round.out_room_player_ids
    idx = round.current_turn_index
    steps = 0
    while steps < n
      idx = (idx - 1 + n) % n
      return order[idx] unless out.include?(order[idx].to_s)

      steps += 1
    end
    nil
  end

  def next_room_player_id(round)
    order = round.turn_order
    n = order.size
    return nil if n.zero?

    out = round.out_room_player_ids
    idx = next_active_index(order, out, round.current_turn_index)
    order[idx]
  end

  def advance!(round, skip: 1)
    n = round.turn_order.size
    return round if n < 2

    out = round.out_room_player_ids
    idx = round.current_turn_index
    skip.times do
      idx = next_active_index(round.turn_order, out, idx)
    end
    payload = (round.payload || {}).except("turn_single_draw_used", "drew_from_deck_this_turn", "six_followup_continue")
    round.update!(current_turn_index: idx, payload: payload)
    round
  end

  def next_active_index(turn_order, out_ids, from_idx)
    n = turn_order.size
    out_set = out_ids.map(&:to_s).to_set
    idx = from_idx
    loop do
      idx = (idx + 1) % n
      break unless out_set.include?(turn_order[idx].to_s)
    end
    idx
  end
  module_function :next_active_index
end
