import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    const text = this.textValue
    if (!text) return

    const done = () => {
      const prev = this.element.textContent
      this.element.textContent = "Copied!"
      this.element.disabled = true
      window.setTimeout(() => {
        this.element.textContent = prev
        this.element.disabled = false
      }, 2000)
    }

    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(done).catch(() => this.fallbackSelectCopy(text, done))
    } else {
      this.fallbackSelectCopy(text, done)
    }
  }

  fallbackSelectCopy(text, done) {
    const ta = document.createElement("textarea")
    ta.value = text
    ta.setAttribute("readonly", "")
    ta.style.position = "absolute"
    ta.style.left = "-9999px"
    document.body.appendChild(ta)
    ta.select()
    try {
      document.execCommand("copy")
    } finally {
      document.body.removeChild(ta)
    }
    done()
  }
}
