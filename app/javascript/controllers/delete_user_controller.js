import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "deleteButton"]
  static values = { userId: String }

  connect() {
    console.log("DeleteUserController connected")
  }

  showModal(event) {
    event.preventDefault()
    // Store the user ID from the clicked button
    this.userIdValue = event.currentTarget.dataset.deleteUserIdParam
    
    // Find the button_to form and update its action
    const form = this.formTarget
    form.action = form.action.replace(':user_id', this.userIdValue)
    
    // Show the modal
    this.modalTarget.style.display = "block"
  }

  hideModal(event) {
    event.preventDefault()
    this.modalTarget.style.display = "none"
  }
}