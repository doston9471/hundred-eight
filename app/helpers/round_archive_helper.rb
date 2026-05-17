# frozen_string_literal: true

module RoundArchiveHelper
  ArchiveEntry = Struct.new(
    :room_player_id, :username, :points, :bonus_points, :hand, :hand_breakdown, :calculation,
    :winner, :loser, keyword_init: true
  )

  ArchiveRound = Struct.new(:round, :winner_entry, :loser_entries, :other_entries, keyword_init: true)

  def build_archive_round(round)
    entries = archive_entries_for(round)
    winner_id = round.winner_id&.to_s || round.scoring_summary["winner_id"].to_s
    winner_entry = entries.find { |e| e.room_player_id == winner_id }
    loser_entries = entries.select(&:loser)
    other_entries = entries.reject { |e| e.winner || e.loser }
    ArchiveRound.new(round: round, winner_entry: winner_entry, loser_entries: loser_entries, other_entries: other_entries)
  end

  private

  def archive_entries_for(round)
    stored = round.scoring_summary.presence
    if stored.is_a?(Hash) && stored["entries"].present?
      winner_id = stored["winner_id"].to_s
      loser_ids = Array(stored["loser_ids"]).map(&:to_s)
      stored["entries"].map { |e| entry_from_hash(round, e, winner_id: winner_id, loser_ids: loser_ids) }
    else
      build_entries_from_records(round)
    end
  end

  def entry_from_hash(round, e, winner_id:, loser_ids:)
    rp_id = e["room_player_id"].to_s
    hand = e["hand"] || round.final_hands[rp_id] || []
    breakdown = e["hand_breakdown"].presence || hand_breakdown_for(hand)
    is_winner = rp_id == winner_id
    is_loser = loser_ids.include?(rp_id) || (!is_winner && (hand.any? || e["points"].to_i.positive?))
    ArchiveEntry.new(
      room_player_id: rp_id,
      username: e["username"],
      points: e["points"].to_i,
      bonus_points: e["bonus_points"].to_i,
      hand: hand,
      hand_breakdown: breakdown,
      calculation: e["calculation"].presence || calculation_line(breakdown),
      winner: is_winner,
      loser: is_loser && !is_winner
    )
  end

  def build_entries_from_records(round)
    winner_id = round.winner_id&.to_s
    scored = round.score_entries.includes(room_player: :user).index_by { |se| se.room_player_id.to_s }
    round.round_players.includes(room_player: :user).map do |rp|
      room_p = rp.room_player
      next if room_p.eliminated?

      se = scored[room_p.id.to_s]
      hand = rp.hand_codes.presence || round.final_hands[room_p.id.to_s] || []
      breakdown = hand_breakdown_for(hand)
      points = se&.points || Game::ScoreCalculator.hand_total(hand)
      is_winner = room_p.id.to_s == winner_id
      ArchiveEntry.new(
        room_player_id: room_p.id.to_s,
        username: room_p.user.username,
        points: points,
        bonus_points: se&.bonus_points.to_i,
        hand: hand,
        hand_breakdown: breakdown,
        calculation: calculation_line(breakdown),
        winner: is_winner,
        loser: !is_winner && (hand.any? || points.positive?)
      )
    end.compact
  end

  def hand_breakdown_for(hand)
    Array(hand).map do |code|
      c = Game::Card.parse(code)
      pts = Game::ScoreCalculator.points_for_card(code)
      { "code" => code, "label" => "#{c.rank} of #{c.suit}", "points" => pts }
    end
  end

  def calculation_line(breakdown)
    Array(breakdown).map { |b| "#{b['label']} (#{b['points']})" }.join(" + ")
  end
end
