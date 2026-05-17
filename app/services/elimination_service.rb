# frozen_string_literal: true

class EliminationService
  class << self
    def apply!(room)
      room.room_players.find_each do |rp|
        next if rp.eliminated?

        if rp.total_score == 108
          rp.update!(total_score: 0)
        elsif rp.total_score > 108
          rp.update!(eliminated: true)
        end
      end

      if room.active_non_eliminated_players.count <= 1
        room.update!(status: :finished)
      end
    end
  end
end
