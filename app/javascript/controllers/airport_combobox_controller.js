import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "codeInput", "typeInput"]
  static values = {
    url: String,
    debounce: { type: Number, default: 150 }
  }

  connect() {
    this._timer = null
    this._boundClickOutside = this._clickOutside.bind(this)
    document.addEventListener("click", this._boundClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this._boundClickOutside)
  }

  search() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this._fetch(), this.debounceValue)
  }

  async _fetch() {
    const q = this.inputTarget.value.trim()
    if (q.length < 2) {
      this._clear()
      return
    }
    try {
      const res = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })
      if (!res.ok) { this._clear(); return }
      const results = await res.json()
      this._render(results)
    } catch (_) {
      this._clear()
    }
  }

  _render(results) {
    if (results.length === 0) {
      this._clear()
      return
    }
    this.dropdownTarget.innerHTML = results.map((r) => `
      <li class="px-3 py-2 cursor-pointer hover:bg-gray-100"
          data-type="${this._escape(r.type)}"
          data-code="${this._escape(r.code)}"
          data-action="mousedown->airport-combobox#select">
        <div class="font-medium text-sm">${this._escape(r.display)}</div>
        ${r.secondary ? `<div class="text-xs text-gray-500">${this._escape(r.secondary)}</div>` : ""}
      </li>
    `).join("")
    this.dropdownTarget.classList.remove("hidden")
  }

  select(event) {
    const li = event.currentTarget
    this.typeInputTarget.value = li.dataset.type
    this.codeInputTarget.value = li.dataset.code
    this.inputTarget.value = li.querySelector(".font-medium").textContent
    this._clear()
  }

  _clear() {
    this.dropdownTarget.innerHTML = ""
    this.dropdownTarget.classList.add("hidden")
  }

  _clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this._clear()
    }
  }

  _escape(str) {
    return String(str).replace(/[&<>"']/g, (m) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    }[m]))
  }
}
