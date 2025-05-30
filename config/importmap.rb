# Pin npm packages by running ./bin/importmap
pin "application", to: "application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Pin all controllers in the app/javascript/controllers directory
# pin "hello_controller", to: "controllers/hello_controller.js"
# pin "preferences_controller", to: "controllers/preferences_controller.js"
# pin "delete_user_controller", to: "controllers/delete_user_controller.js"
# pin_all_from "app/javascript/controllers", under: "controllers", to: "controllers/*"
pin_all_from "app/javascript/controllers", under: "controllers"
