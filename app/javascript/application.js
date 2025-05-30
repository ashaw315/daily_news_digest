// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

// Change these lines to use importmap style imports
// Import controllers - remove curly braces and fix paths
import DeleteUserController from "controllers/delete_user_controller"
import PreferencesController from "controllers/preferences_controller"
import DeleteTopicController from "controllers/delete_topic_controller"
import DeleteSourceController from "controllers/delete_source_controller"


// Initialize Stimulus
const application = Application.start();
application.register("preferences", PreferencesController)
application.register("delete-user", DeleteUserController) 
application.register("delete-topic", DeleteTopicController) 
application.register("delete-source", DeleteSourceController) 

export { application };

// Make Stimulus available globally for debugging
window.Stimulus = application;

window.onload = function() {
  // Code to execute after the page is fully loaded
  console.log("Page has fully loaded.");
};

// Prevent default form submissions from navigating to about:blank
// document.addEventListener("turbo:submit-start", (event) => {
//   const form = event.target;
//   if (form.method === "post") {
//     event.preventDefault();
//   }
// });

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
