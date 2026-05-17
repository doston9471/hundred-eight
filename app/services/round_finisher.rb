# frozen_string_literal: true

class RoundFinisher
  class << self
    def call!(round, winner_room_player:)
      round = round.reload
      return if round.status_completed?

      room = round.room

      ActiveRecord::Base.transaction do
        round.round_players.includes(:room_player).each do |rp|
          room_p = rp.room_player
          next if room_p.eliminated?

          points = room_p.id == winner_room_player.id ? 0 : Game::ScoreCalculator.hand_total(rp.hand_codes)

          ScoreEntry.create!(round: round, room_player: room_p, points: points, bonus_points: 0)
          room_p.increment!(:total_score, points)
        end

        last_play = round.card_plays.kind_play.order(:created_at).last
        if last_play&.card_code && Game::Card.parse(last_play.card_code).queen_of_hearts? &&
            last_play.round_player.room_player_id == winner_room_player.id
          wp = winner_room_player.reload
          before = wp.total_score
          after = [ before - 40, 0 ].max
          delta = after - before
          wp.update!(total_score: after)
          ScoreEntry.find_by!(round: round, room_player: wp).update!(bonus_points: delta)
        end

        final_hands = {}
        scoring_summary = {
          "winner_id" => winner_room_player.id.to_s,
          "entries" => []
        }

        winner_id = winner_room_player.id.to_s
        loser_ids = []

        round.round_players.includes(room_player: :user).each do |rp|
          room_p = rp.room_player
          next if room_p.eliminated?

          hand = rp.hand_codes
          breakdown = hand.map do |code|
            c = Game::Card.parse(code)
            pts = Game::ScoreCalculator.points_for_card(code)
            { "code" => code, "label" => "#{c.rank} of #{c.suit}", "points" => pts }
          end
          final_hands[room_p.id.to_s] = hand
          entry = ScoreEntry.find_by!(round: round, room_player: room_p)
          rp_id = room_p.id.to_s
          loser_ids << rp_id if rp_id != winner_id && (hand.any? || entry.points.positive?)
          scoring_summary["entries"] << {
            "room_player_id" => rp_id,
            "username" => room_p.user.username,
            "points" => entry.points,
            "bonus_points" => entry.bonus_points,
            "hand" => hand,
            "hand_breakdown" => breakdown,
            "calculation" => breakdown.map { |b| "#{b['label']} (#{b['points']})" }.join(" + ")
          }
        end

        scoring_summary["loser_ids"] = loser_ids
        scoring_summary["round_loser_id"] = loser_ids.max_by do |lid|
          scoring_summary["entries"].find { |e| e["room_player_id"] == lid }&.dig("points").to_i
        end

        round.update!(
          status: :completed,
          winner: winner_room_player,
          final_hands: final_hands,
          scoring_summary: scoring_summary
        )

        worst = round.score_entries.where.not(room_player_id: winner_room_player.id).max_by(&:points)
        room.update!(last_round_loser_room_player_id: worst&.room_player_id)
      end

      EliminationService.apply!(room.reload)
      RoomBroadcaster.full_state(room)
    end
  end
end
