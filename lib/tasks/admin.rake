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
    
    # Confirm the user if they're not confirmed
    unless user.confirmed?
      user.confirm
      puts "User #{email} has been confirmed"
    end
    
    user.update(admin: true)
    puts "User #{email} is now an admin"
    puts "Confirmed: #{user.confirmed?}"
    puts "Admin: #{user.admin?}"
  end
  
  desc "Create a new admin user"
  task create_user: :environment do
    email = ENV['ADMIN_EMAIL'] || 'admin@example.com'
    password = ENV['ADMIN_PASSWORD'] || 'admin123456'
    
    user = User.find_or_create_by(email: email) do |u|
      u.password = password
      u.password_confirmation = password
      u.admin = true
      u.skip_confirmation! if u.respond_to?(:skip_confirmation!)
    end
    
    if user.persisted?
      # Make sure they're admin and confirmed
      user.update(admin: true) unless user.admin?
      user.confirm unless user.confirmed?
      
      puts "Admin user created/updated successfully!"
      puts "Email: #{user.email}"
      puts "Admin: #{user.admin?}"
      puts "Confirmed: #{user.confirmed?}"
    else
      puts "Error creating admin user:"
      puts user.errors.full_messages
    end
  end
  
  desc "Fix existing user - confirm and make admin"
  task fix_user: :environment do
    email = 'ashaw315@gmail.com'
    password = 'newpassword123'
    
    user = User.find_by(email: email)
    
    if user.nil?
      puts "User with email #{email} not found"
      exit
    end
    
    # Reset password and confirm user
    user.password = password
    user.password_confirmation = password
    user.admin = true
    user.confirm if user.respond_to?(:confirm)
    
    if user.save
      puts "User #{email} has been fixed!"
      puts "New password: #{password}"
      puts "Admin: #{user.admin?}"
      puts "Confirmed: #{user.confirmed?}"
    else
      puts "Error fixing user:"
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
        puts "- #{admin.email} (Confirmed: #{admin.confirmed?})"
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