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
end 