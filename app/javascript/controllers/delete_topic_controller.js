import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["modal", "form", "deleteButton"]
    static values = { topicId: String }

  connect() {
    console.log("DeleteTopicController connected")
  }

  showModal(event) {
    event.preventDefault()
    // Store the topic ID from the clicked button
    this.topicIdValue = event.currentTarget.dataset.deleteTopicIdParam
    
    // Find the form and update its action
    const form = this.formTarget
    form.action = form.action.replace(':topic_id', this.topicIdValue)
    
    // Show the modal
    this.modalTarget.style.display = "block"
  }

  hideModal(event) {
    event.preventDefault()
    this.modalTarget.style.display = "none"
  }
}