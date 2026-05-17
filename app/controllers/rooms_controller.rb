# frozen_string_literal: true

class RoomsController < ApplicationController
  include RoundArchiveHelper

  before_action :set_room, only: %i[show archive player_panel start next_round remove_player play suit ace_tail_draw ace_pass optional_draw turn_pass seven_take create_invite]
  before_action :ensure_host, only: %i[start next_round remove_player create_invite]

  def index
    @rooms = Room.joins(:room_players).where(room_players: { user_id: current_user.id }).distinct.order(updated_at: :desc).limit(50)
  end

  def new
  end

  def create
    room = CreateRoomService.call!(host: current_user, name: params.dig(:room, :name))
    redirect_to room_path(room)
  rescue StandardError => e
    redirect_to new_room_path, alert: e.message
  end

  def player_panel
    response.set_header("Cache-Control", "private, no-store")

    @round = @room.rounds.status_in_progress.find_by(id: params.require(:round_id))
    return head :not_found unless @round

    @me = @room.room_players.find_by(user: current_user)
    return head :not_found unless @me

    @rp = @round.round_players.find_by(room_player: @me)
    render layout: false
  end

  def archive
    rounds = @room.rounds.status_completed.order(:number).includes(
      :winner, :score_entries,
      card_plays: { round_player: { room_player: :user } },
      round_players: { room_player: :user }
    )
    @archive_rounds = rounds.map { |r| build_archive_round(r) }
  end

  def show
    @state = ReconnectStateQuery.call(room: @room, user: current_user)
    key = "invite_url_for_room_#{@room.id}"
    session.delete(key) unless @room.waiting?
    @pending_invite_url = session[key] if @room.waiting?
  end

  def start
    GameStarterService.call!(room: @room, host: current_user)
    redirect_to room_path(@room), notice: "Game started."
  rescue StandardError => e
    redirect_to room_path(@room), alert: e.message
  end

  def next_round
    HostNextRoundService.call!(room: @room, host: current_user)
    redirect_to room_path(@room), notice: "Next round started."
  rescue StandardError => e
    redirect_to room_path(@room), alert: e.message
  end

  def remove_player
    rp = @room.room_players.find(params.require(:player_id))
    RemoveRoomPlayerService.call!(room: @room, host: current_user, room_player: rp)
    redirect_to room_path(@room), notice: "Player removed."
  rescue StandardError => e
    redirect_to room_path(@room), alert: e.message
  end

  def play
    round = @room.current_round
    raise "no active round" unless round&.status_in_progress?

    rp = round.round_players.find_by!(room_player: @room.room_players.find_by!(user: current_user))
    result = CardPlayService.play!(round: round, actor_round_player: rp, card_code: params.require(:card_code))
    if result.ok
      redirect_to room_path(@room)
    else
      redirect_to room_path(@room), alert: result.error
    end
  rescue StandardError => e
    redirect_to room_path(@room), alert: e.message
  end

  def suit
    round = @room.current_round
    raise "no active round" unless round&.status_in_progress?

    room_player = @room.room_players.find_by!(user: current_user)
    result = CardPlayService.choose_suit!(round: round, actor_room_player: room_player, suit: params.require(:suit))
    if result.ok
      redirect_to room_path(@room)
    else
      redirect_to room_path(@room), alert: result.error
    end
  end

  def ace_tail_draw
    round = @room.current_round
    raise "no active round" unless round&.status_in_progress?

    rp = round.round_players.find_by!(room_player: @room.room_players.find_by!(user: current_user))
    result = AceTailService.draw_one!(round: round, actor_round_player: rp)
    if result.ok
      redirect_to room_path(@room)
    else
      redirect_to room_path(@room), alert: result.error
    end
  end

  def ace_pass
    round = @room.current_round
    raise "no active round" unless round&.status_in_progress?

    room_player = @room.room_players.find_by!(user: current_user)
    result = AceTailService.pass!(round: round, actor_room_player: room_player)
    if result.ok
      redirect_to room_path(@room)
    else
      redirect_to room_path(@room), alert: result.error
    end
  end

  def optional_draw
    round = @room.current_round
    raise "no active round" unless round&.status_in_progress?

    rp = round.round_players.find_by!(room_player: @room.room_players.find_by!(user: current_user))
    result = TurnOptionService.optional_draw_one!(round: round, actor_round_player: rp)
    if result.ok
      redirect_to room_path(@room)
    else
      redirect_to room_path(@room), alert: result.error
    end
  rescue StandardError => e
    redirect_to room_path(@room), alert: e.message
  end

  def turn_pass
    round = @room.current_round
    raise "no active round" unless round&.status_in_progress?

    room_player = @room.room_players.find_by!(user: current_user)
    result = TurnOptionService.pass_turn!(round: round, actor_room_player: room_player)
    if result.ok
      redirect_to room_path(@room)
    else
      redirect_to room_path(@room), alert: result.error
    end
  rescue StandardError => e
    redirect_to room_path(@room), alert: e.message
  end

  def seven_take
    round = @room.current_round
    raise "no active round" unless round&.status_in_progress?

    rp = round.round_players.find_by!(room_player: @room.room_players.find_by!(user: current_user))
    result = SevenResponseService.take!(round: round, actor_round_player: rp)
    if result.ok
      redirect_to room_path(@room)
    else
      redirect_to room_path(@room), alert: result.error
    end
  rescue StandardError => e
    redirect_to room_path(@room), alert: e.message
  end

  def create_invite
    raw = InviteTokenIssuer.call!(room: @room)
    url = room_join_url(raw)
    session["invite_url_for_room_#{@room.id}"] = url
    redirect_to room_path(@room), notice: "Invite link ready — copy it below."
  end

  private

  def set_room
    @room = Room.find(params[:id])
    return if @room.room_players.exists?(user_id: current_user.id)

    redirect_to rooms_path, alert: "You are not in this room."
    throw :abort
  end

  def ensure_host
    return if @room.host?(current_user)

    redirect_to room_path(@room), alert: "Only the host can do that."
  end
end
