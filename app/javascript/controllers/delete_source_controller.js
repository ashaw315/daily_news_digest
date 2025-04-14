import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["modal", "form", "deleteButton"]
    static values = { sourceId: String }

  connect() {
    console.log("DeleteSourceController connected")
  }

  showModal(event) {
    event.preventDefault()
    // Store the source ID from the clicked button
    this.sourceIdValue = event.currentTarget.dataset.deleteSourceIdParam
    
    // Find the form and update its action
    const form = this.formTarget
    form.action = form.action.replace(':source_id', this.sourceIdValue)
    
    // Show the modal
    this.modalTarget.style.display = "block"
  }

  hideModal(event) {
    event.preventDefault()
    this.modalTarget.style.display = "none"
  }
}