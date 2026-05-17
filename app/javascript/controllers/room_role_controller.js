import { Controller } from "@hotwired/stimulus"

// Turbo broadcasts render without a request, so `current_user` is nil in partials.
// Reads the signed-in user id from [data-room-page] on the room show page and toggles
// host-only vs guest-only blocks inside the replaced shell.
export default class extends Controller {
  static values = { hostId: String }
  static targets = ["hostOnly", "guestOnly"]

  connect() {
    this.applyVisibility()
  }

  applyVisibility() {
    const page = document.querySelector("[data-room-page]")
    const me = page?.dataset?.currentUserId || ""
    const isHost = Boolean(me && this.hostIdValue === me)

    this.hostOnlyTargets.forEach((el) => el.classList.toggle("hidden", !isHost))
    this.guestOnlyTargets.forEach((el) => el.classList.toggle("hidden", isHost))
  }
}
