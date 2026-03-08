import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const key = event.currentTarget.dataset.key
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.key === key
      tab.classList.toggle("active", active)
      tab.setAttribute("aria-selected", active.toString())
    })
    this.panelTargets.forEach((panel) => panel.classList.toggle("active", panel.dataset.key === key))
  }
}
