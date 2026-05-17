# frozen_string_literal: true

module Game
  module SevenChain
    module_function

    def merge_start(payload, root_room_player_id:)
      (payload || {}).except("seven_chain_root_id", "seven_chain_source_id", "seven_chain_sevens").merge(
        "seven_chain_root_id" => root_room_player_id.to_s,
        "seven_chain_sevens" => 1
      )
    end

    def merge_stack(payload, root_room_player_id:)
      (payload || {}).merge(
        "seven_chain_root_id" => root_room_player_id.to_s,
        "seven_chain_sevens" => ((payload || {})["seven_chain_sevens"].to_i.positive? ? payload["seven_chain_sevens"].to_i : 1) + 1
      )
    end
  end
end
