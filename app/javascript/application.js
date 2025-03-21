// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import { Application } from "@hotwired/stimulus";
import PreferencesController from "./controllers/preferences_controller";


import "hello_controller" // Import the HelloController
import "preferences_controller" // Import the PreferencesController

// Initialize Stimulus
const application = Application.start();
application.register("preferences", PreferencesController);

export { application };

// Make Stimulus available globally for debugging
window.Stimulus = application;

window.onload = function() {
  // Code to execute after the page is fully loaded
  console.log("Page has fully loaded.");
};

// Prevent default form submissions from navigating to about:blank
document.addEventListener("turbo:submit-start", (event) => {
  const form = event.target;
  if (form.method === "post") {
    event.preventDefault();
  }
});

// Ensure reset button logs when clicked
document.addEventListener("turbo:load", () => {
  console.log("turbo:load event fired");
  
  const resetButton = document.querySelector("button.reset-form");
  console.log("Reset button found:", resetButton);
  
  if (resetButton) {
    resetButton.addEventListener("click", () => {
      console.log("Reset button clicked");
    });
  
  }
});

// Configure Stimulus development experience
application.debug = false;
