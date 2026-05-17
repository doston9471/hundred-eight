import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static values = { roomId: String }

  connect() {
    this.subscription = consumer.subscriptions.create({
      channel: "RoomChannel",
      room_id: this.roomIdValue
    })
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }
}
