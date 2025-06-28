namespace :admin do
  desc "Make a user an admin"
  task :create, [:email] => :environment do |t, args|
    email = args[:email]
    
    if email.blank?
      puts "Please provide an email address: rake admin:create[user@example.com]"
      exit
    end
    
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User with email #{email} not found"
      exit
    end
    
    user.update(admin: true)
    puts "User #{email} is now an admin"
  end
  
  desc "Create a new admin user"
  task create_user: :environment do
    email = ENV['ADMIN_EMAIL'] || 'admin@example.com'
    password = ENV['ADMIN_PASSWORD'] || 'admin123456'
    
    user = User.find_or_create_by(email: email) do |u|
      u.password = password
      u.password_confirmation = password
      u.admin = true
    end
    
    if user.persisted?
      # Make sure they're admin even if user already existed
      user.update(admin: true) unless user.admin?
      puts "Admin user created/updated successfully!"
      puts "Email: #{user.email}"
      puts "Admin: #{user.admin?}"
    else
      puts "Error creating admin user:"
      puts user.errors.full_messages
    end
  end
  
  desc "List all admin users"
  task list: :environment do
    admins = User.where(admin: true)
    
    if admins.empty?
      puts "No admin users found"
    else
      puts "Admin users:"
      admins.each do |admin|
        puts "- #{admin.email}"
      end
    end
  end

  desc "Delete articles older than 24 hours"
  task purge_old_articles: :environment do
    cutoff = 24.hours.ago
    deleted = Article.where("created_at < ?", cutoff).delete_all
    puts "Deleted #{deleted} articles older than 24 hours."
  end
end