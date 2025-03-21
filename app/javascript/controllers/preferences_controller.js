import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    console.log("PreferencesController connected")
  }

//   showResetModal(event) {
//     console.log("showResetModal called", event)
//     event.preventDefault()
//     console.log("Modal before:", this.modalTarget.style.display)
//     this.modalTarget.style.display = 'block'
//     console.log("Modal after:", this.modalTarget.style.display)
//   }

showResetModal(event) {
    console.log("showResetModal called", event)
    event.preventDefault()
  
    console.log("Modal target:", this.modalTarget) // Debugging
  
    if (!this.modalTarget) {
      console.error("Modal target not found!")
      return
    }
  
    this.modalTarget.style.display = "block"
  }

  hideResetModal(event) {
    event.preventDefault()
    this.modalTarget.style.display = 'none'
  }
}